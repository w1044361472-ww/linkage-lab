import { DefaultData } from '../data/Defaults';
import {
  AutomationRule,
  CompareOperator,
  DeviceState,
  EnvMetric,
  RuleAction,
  RuleCondition,
  cloneAction,
  cloneCondition
} from '../model/Models';
import { Palette } from '../theme/Palette';

@Component
export struct RuleEditor {
  @Prop initialRule: AutomationRule;
  @Prop devices: DeviceState[];
  onSave: (rule: AutomationRule) => void = (rule: AutomationRule): void => {
  };
  onCancel: () => void = (): void => {
  };
  @State ruleId: string = '';
  @State revision: number = 0;
  @State ruleName: string = '';
  @State ruleEnabled: boolean = true;
  @State priority: number = 20;
  @State conditions: RuleCondition[] = [];
  @State actions: RuleAction[] = [];
  @State errorText: string = '';

  aboutToAppear(): void {
    this.ruleId = this.initialRule.id;
    this.revision = this.initialRule.revision;
    this.ruleName = this.initialRule.name;
    this.ruleEnabled = this.initialRule.enabled;
    this.priority = this.initialRule.priority;
    const conditions: RuleCondition[] = [];
    for (let i = 0; i < this.initialRule.conditions.length; i++) {
      conditions.push(cloneCondition(this.initialRule.conditions[i]));
    }
    this.conditions = conditions;
    const actions: RuleAction[] = [];
    for (let i = 0; i < this.initialRule.actions.length; i++) {
      actions.push(cloneAction(this.initialRule.actions[i]));
    }
    this.actions = actions;
  }

  private metrics(): EnvMetric[] {
    return [EnvMetric.TEMPERATURE, EnvMetric.HUMIDITY, EnvMetric.ILLUMINANCE, EnvMetric.CO2];
  }

  private operators(): CompareOperator[] {
    return [CompareOperator.GT, CompareOperator.GTE, CompareOperator.LT, CompareOperator.LTE];
  }

  private metricIndex(metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return 0;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return 1;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return 2;
    }
    return 3;
  }


  private operatorSymbol(operator: CompareOperator): string {
    if (operator === CompareOperator.GT) {
      return '>';
    }
    if (operator === CompareOperator.GTE) {
      return '≥';
    }
    if (operator === CompareOperator.LT) {
      return '<';
    }
    return '≤';
  }

  private deviceAt(action: RuleAction): DeviceState | null {
    return DefaultData.findDevice(this.devices, action.deviceId);
  }

  private actionValueNumber(action: RuleAction): number {
    const device = this.deviceAt(action);
    if (device === null) {
      return 0;
    }
    return this.actionValue(action, device);
  }

  private actionValue(action: RuleAction, device: DeviceState): number {
    if (action.value !== undefined) {
      return action.value;
    }
    return device.value;
  }

  private actionHasValue(action: RuleAction): boolean {
    const device = this.deviceAt(action);
    return device !== null && device.hasValue;
  }

  private actionHasPower(action: RuleAction): boolean {
    const device = this.deviceAt(action);
    return device !== null && device.hasPower;
  }

  private actionMin(action: RuleAction): number {
    const device = this.deviceAt(action);
    return device === null ? 0 : device.minValue;
  }

  private actionMax(action: RuleAction): number {
    const device = this.deviceAt(action);
    return device === null ? 100 : device.maxValue;
  }

  private actionUnit(action: RuleAction): string {
    const device = this.deviceAt(action);
    return device === null ? '' : device.unit;
  }

  private actionValueLabel(action: RuleAction): string {
    const device = this.deviceAt(action);
    return device === null ? '数值' : device.valueLabel;
  }

  private rebuildConditions(next: RuleCondition[]): void {
    this.conditions = next;
  }

  private updateConditionMetric(index: number, metric: EnvMetric): void {
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const current = this.conditions[i];
      if (i === index) {
        next.push(DefaultData.newCondition(metric));
      } else {
        next.push(cloneCondition(current));
      }
    }
    this.rebuildConditions(next);
  }

  private updateConditionOperator(index: number, operator: CompareOperator): void {
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const current = cloneCondition(this.conditions[i]);
      if (i === index) {
        current.operator = operator;
      }
      next.push(current);
    }
    this.rebuildConditions(next);
  }

  private updateConditionValue(index: number, value: number): void {
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const current = cloneCondition(this.conditions[i]);
      if (i === index) {
        current.value = Math.round(value);
      }
      next.push(current);
    }
    this.rebuildConditions(next);
  }

  private addCondition(): void {
    if (this.conditions.length >= 2) {
      return;
    }
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      next.push(cloneCondition(this.conditions[i]));
    }
    next.push(DefaultData.newCondition(EnvMetric.HUMIDITY));
    this.rebuildConditions(next);
  }

  private removeCondition(index: number): void {
    if (this.conditions.length <= 1) {
      return;
    }
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      if (i !== index) {
        next.push(cloneCondition(this.conditions[i]));
      }
    }
    this.rebuildConditions(next);
  }

  private rebuildActions(next: RuleAction[]): void {
    this.actions = next;
  }

  private updateActionDevice(index: number, device: DeviceState): void {
    const next: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      if (i === index) {
        next.push(DefaultData.newRuleAction(device));
      } else {
        next.push(cloneAction(this.actions[i]));
      }
    }
    this.rebuildActions(next);
  }

  private updateActionPower(index: number, power: boolean): void {
    const next: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      const current = cloneAction(this.actions[i]);
      if (i === index) {
        current.power = power;
      }
      next.push(current);
    }
    this.rebuildActions(next);
  }

  private updateActionValue(index: number, value: number): void {
    const next: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      const current = cloneAction(this.actions[i]);
      if (i === index) {
        current.value = Math.round(value);
      }
      next.push(current);
    }
    this.rebuildActions(next);
  }

  private addAction(): void {
    if (this.actions.length >= 3 || this.devices.length === 0) {
      return;
    }
    const next: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      next.push(cloneAction(this.actions[i]));
    }
    next.push(DefaultData.newRuleAction(this.devices[0]));
    this.rebuildActions(next);
  }

  private removeAction(index: number): void {
    if (this.actions.length <= 1) {
      return;
    }
    const next: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      if (i !== index) {
        next.push(cloneAction(this.actions[i]));
      }
    }
    this.rebuildActions(next);
  }

  private submit(): void {
    if (this.ruleName.trim().length === 0) {
      this.errorText = '请为规则填写一个名称。';
      return;
    }
    if (this.conditions.length === 0) {
      this.errorText = '规则至少需要一个触发条件。';
      return;
    }
    if (this.actions.length === 0) {
      this.errorText = '规则至少需要一个执行动作。';
      return;
    }
    const conditions: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      conditions.push(cloneCondition(this.conditions[i]));
    }
    const actions: RuleAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      actions.push(cloneAction(this.actions[i]));
    }
    const rule: AutomationRule = {
      id: this.ruleId,
      name: this.ruleName.trim(),
      enabled: this.ruleEnabled,
      priority: Math.round(this.priority),
      conditions: conditions,
      actions: actions,
      revision: this.revision + 1
    };
    this.onSave(rule);
  }

  @Builder
  sectionTitle(index: string, title: string, hint: string) {
    Row({ space: 8 }) {
      Text(index)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(Palette.ACCENT)
        .width(28)
        .height(22)
        .textAlign(TextAlign.Center)
        .borderRadius(7)
        .backgroundColor(Palette.ACCENT_SOFT)
      Column({ space: 1 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.TEXT_PRIMARY)
        Text(hint)
          .fontSize(10)
          .fontColor(Palette.TEXT_MUTED)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 4, bottom: 2 })
  }

  @Builder
  conditionEditor(condition: RuleCondition, index: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`条件 ${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.TEXT_SECONDARY)
        Blank()
        if (this.conditions.length > 1) {
          Text('移除')
            .fontSize(11)
            .fontColor(Palette.DANGER)
            .onClick(() => {
              this.removeCondition(index);
            })
        }
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.metrics(), (metric: EnvMetric) => {
          Text(DefaultData.metricLabel(metric))
            .fontSize(11)
            .fontColor(condition.metric === metric ? '#03131B' : Palette.TEXT_SECONDARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(9)
            .backgroundColor(condition.metric === metric ? Palette.ACCENT : '#0B1929')
            .onClick(() => {
              this.updateConditionMetric(index, metric);
            })
        }, (metric: EnvMetric) => `${index}-${this.metricIndex(metric)}-${condition.metric === metric}`)
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(this.operators(), (operator: CompareOperator, opIndex: number) => {
          Text(this.operatorSymbol(operator))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(condition.operator === operator ? Palette.ACCENT : Palette.TEXT_MUTED)
            .width(42)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .backgroundColor(condition.operator === operator ? Palette.ACCENT_SOFT : '#0B1929')
            .border({ width: 1, color: condition.operator === operator ? Palette.BORDER_ACTIVE : Palette.BORDER })
            .onClick(() => {
              this.updateConditionOperator(index, operator);
            })
        }, (operator: CompareOperator, opIndex: number) => `${index}-${opIndex}-${condition.operator === operator}`)
        Blank()
        Text(`${condition.value}${DefaultData.metricUnit(condition.metric)}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.TEXT_PRIMARY)
      }
      .width('100%')

      Slider({
        value: condition.value,
        min: DefaultData.metricMin(condition.metric),
        max: DefaultData.metricMax(condition.metric),
        step: DefaultData.metricStep(condition.metric),
        style: SliderStyle.OutSet
      })
        .blockColor(Palette.ACCENT)
        .trackColor('#1B2C44')
        .selectedColor(Palette.ACCENT)
        .trackThickness(4)
        .onChange((value: number) => {
          this.updateConditionValue(index, value);
        })
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor('#0B1929')
    .border({ width: 1, color: Palette.BORDER })
  }

  @Builder
  actionEditor(action: RuleAction, index: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`动作 ${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.TEXT_SECONDARY)
        Blank()
        if (this.actions.length > 1) {
          Text('移除')
            .fontSize(11)
            .fontColor(Palette.DANGER)
            .onClick(() => {
              this.removeAction(index);
            })
        }
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.devices, (device: DeviceState) => {
          Text(device.name)
            .fontSize(11)
            .fontColor(action.deviceId === device.id ? '#03131B' : Palette.TEXT_SECONDARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(9)
            .backgroundColor(action.deviceId === device.id ? device.accent : '#0B1929')
            .onClick(() => {
              this.updateActionDevice(index, device);
            })
        }, (device: DeviceState) => `${index}-${device.id}-${action.deviceId === device.id}`)
      }
      .width('100%')

      if (this.actionHasPower(action)) {
        Row() {
          Text('电源状态')
            .fontSize(11)
            .fontColor(Palette.TEXT_SECONDARY)
          Blank()
          Text(action.power === true ? '开启' : '关闭')
            .fontSize(11)
            .fontColor(action.power === true ? Palette.SUCCESS : Palette.TEXT_MUTED)
          Toggle({ type: ToggleType.Switch, isOn: action.power === true })
            .selectedColor(Palette.SUCCESS)
            .switchPointColor('#FFFFFF')
            .margin({ left: 6 })
            .onChange((isOn: boolean) => {
              this.updateActionPower(index, isOn);
            })
        }
        .width('100%')
      }

      if (this.actionHasValue(action)) {
        Row() {
          Text(this.actionValueLabel(action))
            .fontSize(11)
            .fontColor(Palette.TEXT_SECONDARY)
          Blank()
          Text(`${Math.round(this.actionValueNumber(action))}${this.actionUnit(action)}`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Palette.TEXT_PRIMARY)
        }
        .width('100%')

        Slider({
          value: this.actionValueNumber(action),
          min: this.actionMin(action),
          max: this.actionMax(action),
          step: 1,
          style: SliderStyle.OutSet
        })
          .blockColor(Palette.GOLD)
          .trackColor('#1B2C44')
          .selectedColor(Palette.GOLD)
          .trackThickness(4)
          .onChange((value: number) => {
            this.updateActionValue(index, value);
          })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor('#0B1929')
    .border({ width: 1, color: Palette.BORDER })
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('编排规则')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT_PRIMARY)
          Text('条件全部满足时，按优先级执行设备动作')
            .fontSize(11)
            .fontColor(Palette.TEXT_MUTED)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('取消')
          .fontSize(12)
          .fontColor(Palette.TEXT_SECONDARY)
          .padding(8)
          .onClick(() => {
            this.onCancel();
          })
      }
      .width('100%')
      .padding({ bottom: 10 })

      Scroll() {
        Column({ space: 14 }) {
          this.sectionTitle('01', '基础信息', '规则名称、启停状态与优先级')
          Column({ space: 10 }) {
            TextInput({ text: this.ruleName, placeholder: '例如：闷热除湿' })
              .fontSize(13)
              .fontColor(Palette.TEXT_PRIMARY)
              .placeholderColor(Palette.TEXT_MUTED)
              .backgroundColor('#0B1929')
              .borderRadius(10)
              .maxLength(20)
              .onChange((value: string) => {
                this.ruleName = value;
              })

            Row() {
              Text('启用规则')
                .fontSize(12)
                .fontColor(Palette.TEXT_SECONDARY)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.ruleEnabled })
                .selectedColor(Palette.ACCENT)
                .switchPointColor('#FFFFFF')
                .onChange((isOn: boolean) => {
                  this.ruleEnabled = isOn;
                })
            }
            .width('100%')

            Row() {
              Text('优先级')
                .fontSize(12)
                .fontColor(Palette.TEXT_SECONDARY)
              Blank()
              Text(`${Math.round(this.priority)}`)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Palette.ACCENT)
            }
            .width('100%')

            Slider({
              value: this.priority,
              min: DefaultData.MIN_PRIORITY,
              max: DefaultData.MAX_PRIORITY,
              step: 1,
              style: SliderStyle.OutSet
            })
              .blockColor(Palette.ACCENT)
              .trackColor('#1B2C44')
              .selectedColor(Palette.ACCENT)
              .trackThickness(4)
              .onChange((value: number) => {
                this.priority = value;
              })
          }
          .width('100%')

          Divider().color(Palette.BORDER).strokeWidth(1)

          this.sectionTitle('02', '触发条件', '最多两条，条件之间为「且」关系')
          if (this.conditions.length > 0) {
            this.conditionEditor(this.conditions[0], 0)
          }
          if (this.conditions.length > 1) {
            Row({ space: 8 }) {
              Divider().color(Palette.BORDER).strokeWidth(1).layoutWeight(1)
              Text('AND')
                .fontSize(9)
                .letterSpacing(1.4)
                .fontColor(Palette.TEXT_MUTED)
              Divider().color(Palette.BORDER).strokeWidth(1).layoutWeight(1)
            }
            .width('100%')
            this.conditionEditor(this.conditions[1], 1)
          }
          if (this.conditions.length < 2) {
            Text('+ 增加第二个条件')
              .fontSize(11)
              .fontColor(Palette.ACCENT)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(9)
              .borderRadius(10)
              .backgroundColor('#0B1929')
              .border({ width: 1, color: Palette.BORDER })
              .onClick(() => {
                this.addCondition();
              })
          }

          Divider().color(Palette.BORDER).strokeWidth(1)

          this.sectionTitle('03', '执行动作', '按顺序改变设备状态，最多三个动作')
          if (this.actions.length > 0) {
            this.actionEditor(this.actions[0], 0)
          }
          if (this.actions.length > 1) {
            this.actionEditor(this.actions[1], 1)
          }
          if (this.actions.length > 2) {
            this.actionEditor(this.actions[2], 2)
          }
          if (this.actions.length < 3) {
            Text('+ 增加执行动作')
              .fontSize(11)
              .fontColor(Palette.ACCENT)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(9)
              .borderRadius(10)
              .backgroundColor('#0B1929')
              .border({ width: 1, color: Palette.BORDER })
              .onClick(() => {
                this.addAction();
              })
          }

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(11)
              .fontColor(Palette.DANGER)
              .width('100%')
          }

          Text('提示：同一设备的同一控制字段被多条规则命中时，数值较大的优先级生效，其余动作会记入冲突日志。')
            .fontSize(10)
            .fontColor(Palette.TEXT_MUTED)
            .lineHeight(16)
            .width('100%')
            .padding(10)
            .borderRadius(10)
            .backgroundColor('#0B1929')
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(13)
          .fontColor(Palette.TEXT_SECONDARY)
          .backgroundColor('#0B1929')
          .border({ width: 1, color: Palette.BORDER })
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.onCancel();
          })
        Button('保存规则')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#03131B')
          .backgroundColor(Palette.ACCENT)
          .height(44)
          .layoutWeight(2)
          .onClick(() => {
            this.submit();
          })
      }
      .width('100%')
      .padding({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 10 })
    .backgroundColor(Palette.BACKGROUND)
  }
}


