import { RuleEngine } from '../engine/RuleEngine';
import { AutomationRule, DeviceState } from '../model/Models';
import { Palette } from '../theme/Palette';

@Component
export struct RuleCard {
  @Prop rule: AutomationRule;
  @Prop devices: DeviceState[];
  @Prop overlapText: string;
  onToggle: (ruleId: string, enabled: boolean) => void = (ruleId: string, enabled: boolean): void => {
  };
  onEdit: (rule: AutomationRule) => void = (rule: AutomationRule): void => {
  };
  onDelete: (rule: AutomationRule) => void = (rule: AutomationRule): void => {
  };

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Switch, isOn: this.rule.enabled })
          .selectedColor(Palette.ACCENT)
          .switchPointColor('#FFFFFF')
          .onChange((isOn: boolean) => {
            this.onToggle(this.rule.id, isOn);
          })

        Column({ space: 2 }) {
          Text(this.rule.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT_PRIMARY)
          Text(this.rule.enabled ? '规则已启用' : '规则已停用')
            .fontSize(10)
            .fontColor(this.rule.enabled ? Palette.SUCCESS : Palette.TEXT_MUTED)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`P${this.rule.priority}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.ACCENT)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(9)
          .backgroundColor(Palette.ACCENT_SOFT)
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('IF')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.ACCENT)
          .width(24)
        Text(RuleEngine.describeRuleConditions(this.rule))
          .fontSize(12)
          .fontColor(Palette.TEXT_SECONDARY)
          .lineHeight(18)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        Text('THEN')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.SUCCESS)
          .width(34)
        Text(RuleEngine.describeRuleActions(this.rule, this.devices))
          .fontSize(12)
          .fontColor(Palette.TEXT_PRIMARY)
          .lineHeight(18)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.overlapText.length > 0) {
        Row({ space: 6 }) {
          Text('!')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.WARNING)
          Text(this.overlapText)
            .fontSize(10)
            .fontColor(Palette.WARNING)
            .lineHeight(15)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(8)
        .borderRadius(9)
        .backgroundColor('#2A2113')
      }

      Divider().color(Palette.BORDER).strokeWidth(1)

      Row() {
        Text('编辑')
          .fontSize(12)
          .fontColor(Palette.ACCENT)
          .padding({ top: 5, bottom: 5, left: 2, right: 10 })
          .onClick(() => {
            this.onEdit(this.rule);
          })
        Blank()
        Text('删除')
          .fontSize(12)
          .fontColor(Palette.DANGER)
          .padding({ top: 5, bottom: 5, left: 10, right: 2 })
          .onClick(() => {
            this.onDelete(this.rule);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(15)
    .borderRadius(18)
    .backgroundColor(Palette.CARD)
    .border({ width: 1, color: this.rule.enabled ? Palette.BORDER : '#162132' })
    .opacity(this.rule.enabled ? 1 : 0.6)
    .animation({ duration: 220, curve: Curve.EaseOut })
  }
}
