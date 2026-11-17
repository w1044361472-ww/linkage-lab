import { common } from '@kit.AbilityKit';
import { Formatters } from '../common/Formatters';
import { EnvironmentPanel } from '../components/EnvironmentPanel';
import { LogCard } from '../components/LogCard';
import { RuleCard } from '../components/RuleCard';
import { RuleEditor } from '../components/RuleEditor';
import { ScenarioCard } from '../components/ScenarioCard';
import { DefaultData } from '../data/Defaults';
import { RuleEngine } from '../engine/RuleEngine';
import {
  AutomationRule,
  ConflictRecord,
  DeviceKind,
  DeviceState,
  EnvMetric,
  EnvironmentState,
  ExecutionRecord,
  PersistedState,
  ScenarioPreset,
  cloneDevice,
  cloneEnvironment,
  cloneRule,
  cloneRules
} from '../model/Models';
import { PreferencesRepository } from '../storage/PreferencesRepository';
import { Palette } from '../theme/Palette';

@Entry
@Component
struct Index {
  @State environment: EnvironmentState = DefaultData.environment();
  @State devices: DeviceState[] = DefaultData.devices();
  @State rules: AutomationRule[] = DefaultData.rules();
  @State logs: ExecutionRecord[] = [];
  @State currentTab: number = 0;
  @State loading: boolean = true;
  @State saveHint: string = '正在读取本地存档';
  @State lastRunVisible: boolean = false;
  @State lastSummary: string = '';
  @State lastConflicts: ConflictRecord[] = [];
  @State lastExecutedNames: string[] = [];
  @State lastScenario: string = '';
  @State editorVisible: boolean = false;
  @State editingRule: AutomationRule = DefaultData.blankRule('draft-rule');
  @State editorKey: string = 'editor-init';
  private scenarios: ScenarioPreset[] = DefaultData.scenarios();
  private repo: PreferencesRepository = PreferencesRepository.getInstance();
  private saveTimer: number = -1;

  aboutToAppear(): void {
    this.loadState();
  }

  aboutToDisappear(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
    }
    this.persistNow();
  }

  private async loadState(): Promise<void> {
    const context = AppStorage.get<common.UIAbilityContext>('labAbilityContext');
    if (context === undefined) {
      this.loading = false;
      this.saveHint = '本地存储不可用';
      return;
    }
    try {
      await this.repo.init(context);
      const state = await this.repo.load();
      if (state !== null) {
        this.environment = state.environment;
        this.devices = state.devices;
        this.rules = state.rules;
        this.logs = state.logs;
        this.saveHint = '已恢复上次进度';
        if (state.logs.length > 0) {
          const latest = state.logs[0];
          this.lastRunVisible = true;
          this.lastSummary = latest.summary;
          this.lastConflicts = latest.conflicts;
          this.lastExecutedNames = latest.executedRuleNames;
          this.lastScenario = latest.scenario;
        }
      } else {
        this.environment = DefaultData.environment();
        this.devices = DefaultData.devices();
        this.rules = DefaultData.rules();
        this.logs = [];
        this.saveHint = '已载入演示数据';
        await this.repo.save(this.buildState());
      }
    } catch (error) {
      this.saveHint = '读取失败，使用演示数据';
    } finally {
      this.loading = false;
    }
  }

  private buildState(): PersistedState {
    const logs: ExecutionRecord[] = [];
    for (let i = 0; i < this.logs.length && i < DefaultData.MAX_LOGS; i++) {
      logs.push(this.logs[i]);
    }
    const state: PersistedState = {
      version: DefaultData.VERSION,
      environment: cloneEnvironment(this.environment),
      devices: this.devices,
      rules: cloneRules(this.rules),
      logs: logs
    };
    return state;
  }

  private persistNow(): void {
    if (this.loading || !this.repo.isReady()) {
      return;
    }
    this.repo.save(this.buildState()).then(() => {
      this.saveHint = `已保存 ${Formatters.clock(Date.now())}`;
    }).catch((error: Error) => {
      this.saveHint = '本地保存失败';
    });
  }

  private schedulePersist(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.persistNow();
    }, 260);
  }

  private handleMetricChange(metric: EnvMetric, value: number): void {
    const next = cloneEnvironment(this.environment);
    if (metric === EnvMetric.TEMPERATURE) {
      next.temperature = value;
    } else if (metric === EnvMetric.HUMIDITY) {
      next.humidity = value;
    } else if (metric === EnvMetric.ILLUMINANCE) {
      next.illuminance = value;
    } else {
      next.co2 = value;
    }
    this.environment = next;
  }

  private handleDevicePower(deviceId: string, power: boolean): void {
    const next: DeviceState[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const device = cloneDevice(this.devices[i]);
      if (device.id === deviceId) {
        device.power = power;
      }
      next.push(device);
    }
    this.devices = next;
    this.persistNow();
  }

  private deviceStep(device: DeviceState): number {
    if (device.kind === DeviceKind.LIGHT || device.kind === DeviceKind.CURTAIN) {
      return 5;
    }
    return 1;
  }

  private handleDeviceValue(deviceId: string, value: number): void {
    const next: DeviceState[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const device = cloneDevice(this.devices[i]);
      if (device.id === deviceId) {
        const step = this.deviceStep(device);
        let rounded = Math.round(value / step) * step;
        if (rounded < device.minValue) {
          rounded = device.minValue;
        }
        if (rounded > device.maxValue) {
          rounded = device.maxValue;
        }
        device.value = rounded;
      }
      next.push(device);
    }
    this.devices = next;
    this.schedulePersist();
  }

  private toggleRule(ruleId: string, enabled: boolean): void {
    const next: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === ruleId) {
        const rule = cloneRule(this.rules[i]);
        rule.enabled = enabled;
        rule.revision = rule.revision + 1;
        next.push(rule);
      } else {
        next.push(this.rules[i]);
      }
    }
    this.rules = next;
    this.persistNow();
  }

  private openEditor(rule: AutomationRule): void {
    this.editingRule = cloneRule(rule);
    this.editorKey = `editor-${Date.now()}`;
    this.editorVisible = true;
  }

  private openNewRule(): void {
    this.openEditor(DefaultData.blankRule(`rule-${Date.now()}`));
  }

  private handleRuleSave(rule: AutomationRule): void {
    const next: AutomationRule[] = [];
    let replaced = false;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === rule.id) {
        next.push(rule);
        replaced = true;
      } else {
        next.push(this.rules[i]);
      }
    }
    if (!replaced) {
      next.push(rule);
    }
    this.rules = next;
    this.editorVisible = false;
    this.persistNow();
  }

  private confirmDeleteRule(rule: AutomationRule): void {
    AlertDialog.show({
      title: '删除规则',
      message: `确认删除「${rule.name}」？该规则将不再参与联动计算。`,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Palette.DANGER,
        action: () => {
          this.removeRule(rule.id);
        }
      }
    });
  }

  private removeRule(ruleId: string): void {
    const next: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id !== ruleId) {
        next.push(this.rules[i]);
      }
    }
    this.rules = next;
    this.persistNow();
  }

  private restoreDemoRules(): void {
    this.rules = DefaultData.rules();
    this.persistNow();
  }

  private executeRules(scenarioName: string): void {
    const result = RuleEngine.run(this.rules, this.environment, this.devices);
    this.devices = result.devices;
    const now = Date.now();
    const record: ExecutionRecord = {
      id: `log-${now}`,
      timestamp: now,
      scenario: scenarioName,
      environment: cloneEnvironment(this.environment),
      executedRuleIds: result.executedRuleIds,
      executedRuleNames: result.executedRuleNames,
      executedConditions: result.matchedConditionTexts,
      changes: result.changes,
      conflicts: result.conflicts,
      summary: result.summary
    };
    const nextLogs: ExecutionRecord[] = [record];
    for (let i = 0; i < this.logs.length && nextLogs.length < DefaultData.MAX_LOGS; i++) {
      nextLogs.push(this.logs[i]);
    }
    this.logs = nextLogs;
    this.lastSummary = result.summary;
    this.lastConflicts = result.conflicts;
    this.lastExecutedNames = result.executedRuleNames;
    this.lastScenario = scenarioName;
    this.lastRunVisible = true;
    this.persistNow();
  }

  private runScenario(scenario: ScenarioPreset): void {
    this.environment = cloneEnvironment(scenario.environment);
    this.executeRules(scenario.name);
  }

  private confirmClearLogs(): void {
    if (this.logs.length === 0) {
      return;
    }
    AlertDialog.show({
      title: '清空日志',
      message: '执行记录清空后不可恢复，设备状态与规则仍会保留。',
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: Palette.DANGER,
        action: () => {
          this.logs = [];
          this.lastRunVisible = false;
          this.persistNow();
        }
      }
    });
  }

  private activeRuleCount(): number {
    let count = 0;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].enabled) {
        count++;
      }
    }
    return count;
  }

  private poweredCount(): number {
    let count = 0;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].hasPower && this.devices[i].power) {
        count++;
      }
    }
    return count;
  }

  private overlapCount(): number {
    return RuleEngine.findOverlaps(this.rules, this.devices).length;
  }

  private sortedRules(): AutomationRule[] {
    const sorted: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      sorted.push(this.rules[i]);
    }
    sorted.sort((left: AutomationRule, right: AutomationRule): number => {
      if (right.priority !== left.priority) {
        return right.priority - left.priority;
      }
      if (left.id < right.id) {
        return -1;
      }
      if (left.id > right.id) {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  private kindLabel(kind: DeviceKind): string {
    if (kind === DeviceKind.LIGHT) {
      return '照明设备';
    }
    if (kind === DeviceKind.AC) {
      return '温控设备';
    }
    if (kind === DeviceKind.CURTAIN) {
      return '遮阳设备';
    }
    if (kind === DeviceKind.HUMIDIFIER) {
      return '加湿设备';
    }
    return '空气设备';
  }

  private switchTab(index: number): void {
    this.currentTab = index;
  }

  @Builder
  loadingView() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(42)
        .height(42)
        .color(Palette.ACCENT)
      Text('正在恢复本地沙盘')
        .fontSize(13)
        .fontColor(Palette.TEXT_SECONDARY)
      Text('规则、设备状态与执行记录将从 Preferences 读取')
        .fontSize(10)
        .fontColor(Palette.TEXT_MUTED)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Row({ space: 7 }) {
          Rect({ width: 14, height: 3, radius: 2 }).fill(Palette.ACCENT)
          Text('LINKAGE LAB')
            .fontSize(9)
            .letterSpacing(2)
            .fontColor(Palette.ACCENT)
        }

        Text('栖光联动实验室')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.TEXT_PRIMARY)
        Text('智能宿舍自动化规则沙盘')
          .fontSize(11)
          .fontColor(Palette.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Column({ space: 4 }) {
        Row({ space: 5 }) {
          Circle({ width: 6, height: 6 })
            .fill(this.repo.isReady() ? Palette.SUCCESS : Palette.WARNING)
          Text(this.repo.isReady() ? '本地存档' : '演示模式')
            .fontSize(10)
            .fontColor(Palette.TEXT_SECONDARY)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(10)
        .backgroundColor('#0E1C2B')

        Text(this.saveHint)
          .fontSize(9)
          .fontColor(Palette.TEXT_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(120)
          .textAlign(TextAlign.End)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 10 })
  }

  @Builder
  statCell(label: string, value: string, accent: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
      Text(label)
        .fontSize(9)
        .fontColor(Palette.TEXT_MUTED)
    }
    .layoutWeight(1)
  }

  @Builder
  statStrip(logCount: number) {
    Row() {
      this.statCell('规则总数', `${this.rules.length}`, Palette.ACCENT)
      Divider().vertical(true).height(26).color(Palette.BORDER)
      this.statCell('启用', `${this.activeRuleCount()}`, Palette.SUCCESS)
      Divider().vertical(true).height(26).color(Palette.BORDER)
      this.statCell('设备在线', `${this.poweredCount()}`, Palette.GOLD)
      Divider().vertical(true).height(26).color(Palette.BORDER)
      this.statCell('执行记录', `${logCount}`, Palette.PURPLE)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 8, right: 8 })
    .borderRadius(16)
    .backgroundColor(Palette.SURFACE)
    .border({ width: 1, color: Palette.BORDER })
  }

  @Builder
  runResultBanner() {
    Column({ space: 8 }) {
      Row() {
        Row({ space: 6 }) {
          Circle({ width: 6, height: 6 }).fill(this.lastConflicts.length > 0 ? Palette.WARNING : Palette.SUCCESS)
          Text('最近联动')
            .fontSize(10)
            .fontColor(Palette.TEXT_SECONDARY)
        }

        Blank()
        Text(this.lastScenario)
          .fontSize(10)
          .fontColor(Palette.ACCENT)
      }
      .width('100%')

      Text(this.lastSummary)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.TEXT_PRIMARY)
        .lineHeight(18)
        .width('100%')

      if (this.lastExecutedNames.length > 0) {
        Text(Formatters.executionOrder(this.lastExecutedNames))
          .fontSize(10)
          .fontColor(Palette.TEXT_SECONDARY)
          .lineHeight(16)
          .width('100%')
      }

      if (this.lastConflicts.length > 0) {
        Row({ space: 6 }) {
          Text('!')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.WARNING)
          Text(`${this.lastConflicts.length} 处控制冲突已按优先级仲裁，详情见执行日志。`)
            .fontSize(10)
            .fontColor('#D7B27A')
            .layoutWeight(1)
        }
        .width('100%')
      }

      Row() {
        Blank()
        Text('查看完整日志 →')
          .fontSize(10)
          .fontColor(Palette.ACCENT)
          .onClick(() => {
            this.switchTab(2);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(16)
    .backgroundColor('#0C2231')
    .border({ width: 1, color: this.lastConflicts.length > 0 ? '#5A4726' : Palette.BORDER_ACTIVE })
  }

  @Builder
  deviceCard(device: DeviceState) {
    Column() {
      Row({ space: 9 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 36, height: 36 })
            .fill('#0A1929')
            .border({ width: 1, color: '#22384F' })
          Text(device.shortName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(device.accent)
        }

        Column({ space: 2 }) {
          Text(device.name)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT_PRIMARY)
          Text(this.kindLabel(device.kind))
            .fontSize(9)
            .fontColor(Palette.TEXT_MUTED)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        if (device.hasPower) {
          Toggle({ type: ToggleType.Switch, isOn: device.power })
            .selectedColor(device.accent)
            .switchPointColor('#FFFFFF')
            .onChange((isOn: boolean) => {
              this.handleDevicePower(device.id, isOn);
            })
        } else {
          Text('常驻')
            .fontSize(9)
            .fontColor(Palette.TEXT_MUTED)
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .borderRadius(7)
            .backgroundColor('#0A1929')
        }
      }
      .width('100%')

      if (device.hasValue) {
        Row() {
          Text(device.valueLabel)
            .fontSize(10)
            .fontColor(Palette.TEXT_MUTED)
          Blank()
          Text(`${Math.round(device.value)}${device.unit}`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Palette.TEXT_PRIMARY)
        }
        .width('100%')
        .margin({ top: 10 })

        Slider({
          value: device.value,
          min: device.minValue,
          max: device.maxValue,
          step: this.deviceStep(device),
          style: SliderStyle.OutSet
        })
          .blockColor(device.accent)
          .trackColor('#1B2C44')
          .selectedColor(device.accent)
          .trackThickness(3)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.handleDeviceValue(device.id, value);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.persistNow();
            }
          })
      } else {
        Text('开关型设备')
          .fontSize(10)
          .fontColor(Palette.TEXT_MUTED)
          .width('100%')
          .padding({ top: 12, bottom: 12 })
      }

      Blank()

      Row({ space: 5 }) {
        Circle({ width: 5, height: 5 })
          .fill(device.hasPower ? (device.power ? Palette.SUCCESS : Palette.TEXT_MUTED) : Palette.PURPLE)
        Text(device.hasPower ? (device.power ? '运行中' : '待机') : '可调节')
          .fontSize(9)
          .fontColor(Palette.TEXT_MUTED)
        Blank()
        Text(device.hasValue ? `预设 ${Math.round(device.value)}${device.unit}` : '开关控制')
          .fontSize(9)
          .fontColor(Palette.TEXT_MUTED)
      }
      .width('100%')
    }
    .width('48.4%')
    .height(174)
    .padding(13)
    .margin({ bottom: 11 })
    .borderRadius(18)
    .backgroundColor(Palette.CARD)
    .border({ width: 1, color: device.power ? '#28506A' : Palette.BORDER })
    .animation({ duration: 260, curve: Curve.EaseOut })
  }

  @Builder
  labPage() {
    Scroll() {
      Column({ space: 14 }) {
        this.statStrip(this.logs.length)

        Row() {
          Column({ space: 2 }) {
            Text('场景演练')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('一键注入环境并执行联动')
              .fontSize(10)
              .fontColor(Palette.TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(`${this.scenarios.length} 组预设`)
            .fontSize(10)
            .fontColor(Palette.TEXT_SECONDARY)
        }
        .width('100%')

        List({ space: 10 }) {
          ForEach(this.scenarios, (scenario: ScenarioPreset) => {
            ListItem() {
              ScenarioCard({
                scenario: scenario,
                onRun: (selected: ScenarioPreset) => {
                  this.runScenario(selected);
                }
              })
            }
          }, (scenario: ScenarioPreset) => scenario.id)
        }
        .listDirection(Axis.Horizontal)
        .height(158)
        .scrollBar(BarState.Off)
        .width('100%')

        EnvironmentPanel({
          environment: this.environment,
          onMetricChange: (metric: EnvMetric, value: number) => {
            this.handleMetricChange(metric, value);
          },
          onCommit: () => {
            this.persistNow();
          }
        })

        if (this.lastRunVisible) {
          this.runResultBanner()
        }

        Row() {
          Column({ space: 2 }) {
            Text('设备矩阵')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('点击开关或拖动参数，规则执行时可能被覆盖')
              .fontSize(10)
              .fontColor(Palette.TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(`${this.poweredCount()}/${this.devices.length} 在线`)
            .fontSize(10)
            .fontColor(Palette.SUCCESS)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          if (this.devices.length > 0) {
            this.deviceCard(this.devices[0])
          }
          if (this.devices.length > 1) {
            this.deviceCard(this.devices[1])
          }
          if (this.devices.length > 2) {
            this.deviceCard(this.devices[2])
          }
          if (this.devices.length > 3) {
            this.deviceCard(this.devices[3])
          }
          if (this.devices.length > 4) {
            this.deviceCard(this.devices[4])
          }
        }
        .width('100%')

        Button() {
          Row() {
            Text('执行联动规则')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#03131B')
            Blank()
            Text(`${this.activeRuleCount()} 条启用规则`)
              .fontSize(10)
              .fontColor('#0A3A4A')
          }
          .width('100%')
          .padding({ left: 18, right: 18 })
        }
        .height(52)
        .width('100%')
        .backgroundColor(Palette.ACCENT)
        .borderRadius(16)
        .onClick(() => {
          this.executeRules('手动执行');
        })

        Text('提示：手动调节只改变设备状态；点击执行后，规则引擎会依据当前 Mock 环境按优先级重新仲裁控制字段。')
          .fontSize(10)
          .fontColor(Palette.TEXT_MUTED)
          .lineHeight(16)
          .width('100%')
          .padding({ bottom: 10 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 6, bottom: 12 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  rulesPage() {
    Scroll() {
      Column({ space: 13 }) {
        Row() {
          Column({ space: 2 }) {
            Text('规则编排')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('优先级越大越先执行，冲突字段由先执行者锁定')
              .fontSize(10)
              .fontColor(Palette.TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button('+ 新建规则')
            .fontSize(11)
            .fontColor('#03131B')
            .fontWeight(FontWeight.Bold)
            .height(34)
            .padding({ left: 13, right: 13 })
            .backgroundColor(Palette.ACCENT)
            .onClick(() => {
              this.openNewRule();
            })
        }
        .width('100%')

        if (this.overlapCount() > 0) {
          Row({ space: 8 }) {
            Text('!')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.WARNING)
            Text(`检测到 ${this.overlapCount()} 处潜在控制重叠，同一设备字段将由优先级更高的规则优先控制。`)
              .fontSize(10)
              .fontColor('#D7B27A')
              .lineHeight(16)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .borderRadius(13)
          .backgroundColor('#241C10')
          .border({ width: 1, color: '#4A3A1E' })
        }

        Row() {
          this.statCell('全部规则', `${this.rules.length}`, Palette.ACCENT)
          Divider().vertical(true).height(26).color(Palette.BORDER)
          this.statCell('启用中', `${this.activeRuleCount()}`, Palette.SUCCESS)
          Divider().vertical(true).height(26).color(Palette.BORDER)
          this.statCell('潜在重叠', `${this.overlapCount()}`, Palette.WARNING)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12, left: 8, right: 8 })
        .borderRadius(16)
        .backgroundColor(Palette.SURFACE)
        .border({ width: 1, color: Palette.BORDER })

        if (this.rules.length === 0) {
          Column({ space: 10 }) {
            Text('还没有可执行的规则')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('新建规则，或载入一组演示规则快速开始。')
              .fontSize(11)
              .fontColor(Palette.TEXT_MUTED)
            Row({ space: 10 }) {
              Button('新建规则')
                .fontSize(11)
                .fontColor('#03131B')
                .backgroundColor(Palette.ACCENT)
                .height(36)
                .onClick(() => {
                  this.openNewRule();
                })
              Button('载入演示规则')
                .fontSize(11)
                .fontColor(Palette.TEXT_SECONDARY)
                .backgroundColor('#0B1929')
                .border({ width: 1, color: Palette.BORDER })
                .height(36)
                .onClick(() => {
                  this.restoreDemoRules();
                })
            }
          }
          .width('100%')
          .padding(22)
          .borderRadius(18)
          .backgroundColor(Palette.CARD)
          .border({ width: 1, color: Palette.BORDER })
        } else {
          ForEach(this.sortedRules(), (rule: AutomationRule) => {
            RuleCard({
              rule: rule,
              devices: this.devices,
              overlapText: RuleEngine.overlapTextForRule(rule.id, this.rules, this.devices),
              onToggle: (ruleId: string, enabled: boolean) => {
                this.toggleRule(ruleId, enabled);
              },
              onEdit: (selected: AutomationRule) => {
                this.openEditor(selected);
              },
              onDelete: (selected: AutomationRule) => {
                this.confirmDeleteRule(selected);
              }
            })
          }, (rule: AutomationRule) => `${rule.id}-${rule.revision}`)
        }

        Text('执行顺序：优先级数值降序 → 规则 ID 升序。相同控制字段被命中时，后执行的动作不会覆盖先执行的动作，并写入冲突记录。')
          .fontSize(10)
          .fontColor(Palette.TEXT_MUTED)
          .lineHeight(16)
          .width('100%')
          .padding({ bottom: 10 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 6, bottom: 12 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  logsPage() {
    Scroll() {
      Column({ space: 13 }) {
        Row() {
          Column({ space: 2 }) {
            Text('执行日志')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('记录环境快照、命中条件、设备变化与冲突仲裁')
              .fontSize(10)
              .fontColor(Palette.TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('清空')
            .fontSize(12)
            .fontColor(this.logs.length > 0 ? Palette.DANGER : Palette.TEXT_MUTED)
            .padding(7)
            .onClick(() => {
              this.confirmClearLogs();
            })
        }
        .width('100%')

        Row() {
          this.statCell('记录数', `${this.logs.length}`, Palette.PURPLE)
          Divider().vertical(true).height(26).color(Palette.BORDER)
          this.statCell('最近场景', this.logs.length > 0 ? this.logs[0].scenario : '暂无', Palette.ACCENT)
          Divider().vertical(true).height(26).color(Palette.BORDER)
          this.statCell('最近并发冲突', this.logs.length > 0 ? `${this.logs[0].conflicts.length}` : '0', Palette.WARNING)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12, left: 8, right: 8 })
        .borderRadius(16)
        .backgroundColor(Palette.SURFACE)
        .border({ width: 1, color: Palette.BORDER })

        if (this.logs.length === 0) {
          Column({ space: 10 }) {
            Text('暂无执行记录')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.TEXT_PRIMARY)
            Text('去实验室调整 Mock 环境，执行一次联动即可生成日志。')
              .fontSize(11)
              .fontColor(Palette.TEXT_MUTED)
            Button('去实验室演练')
              .fontSize(11)
              .fontColor('#03131B')
              .backgroundColor(Palette.ACCENT)
              .height(36)
              .onClick(() => {
                this.switchTab(0);
              })
          }
          .width('100%')
          .padding(22)
          .borderRadius(18)
          .backgroundColor(Palette.CARD)
          .border({ width: 1, color: Palette.BORDER })
        } else {
          ForEach(this.logs, (record: ExecutionRecord) => {
            LogCard({ record: record })
          }, (record: ExecutionRecord) => `${record.id}-${record.timestamp}`)
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 6, bottom: 16 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  navItem(index: number, label: string, code: string) {
    Column({ space: 3 }) {
      Rect({ width: 16, height: 3, radius: 2 })
        .fill(this.currentTab === index ? Palette.ACCENT : Palette.TRANSPARENT)
      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? Palette.TEXT_PRIMARY : Palette.TEXT_MUTED)
      Text(code)
        .fontSize(8)
        .letterSpacing(1.2)
        .fontColor(this.currentTab === index ? Palette.ACCENT : '#33445C')
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchTab(index);
    })
  }

  @Builder
  bottomNav() {
    Row() {
      this.navItem(0, '实验室', 'LAB')
      this.navItem(1, '规则', 'RULES')
      this.navItem(2, '日志', 'LOGS')
    }
    .width('100%')
    .padding({ left: 18, right: 18 })
    .backgroundColor('#080E19')
    .border({ width: { top: 1 }, color: Palette.BORDER })
  }

  @Builder
  ruleEditorSheet() {
    Column() {
      if (this.editorVisible) {
        RuleEditor({
          initialRule: this.editingRule,
          devices: this.devices,
          onSave: (rule: AutomationRule) => {
            this.handleRuleSave(rule);
          },
          onCancel: () => {
            this.editorVisible = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .id(this.editorKey)
  }

  build() {
    Column() {
      if (this.loading) {
        this.loadingView()
      } else {
        Column() {
          this.header()
          Column() {
            if (this.currentTab === 0) {
              this.labPage()
            } else if (this.currentTab === 1) {
              this.rulesPage()
            } else {
              this.logsPage()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .height('100%')
          this.bottomNav()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [['#0C1728', 0.0], ['#070B14', 0.55], ['#0A1424', 1.0]]
    })
    .bindSheet($$this.editorVisible, this.ruleEditorSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: Palette.BACKGROUND,
      onDisappear: () => {
        this.editorVisible = false;
      }
    })
  }
}

