import { ScenarioPreset } from '../model/Models';
import { Palette } from '../theme/Palette';

@Component
export struct ScenarioCard {
  @Prop scenario: ScenarioPreset;
  onRun: (scenario: ScenarioPreset) => void = (scenario: ScenarioPreset): void => {
  };

  private environmentLine(): string {
    const env = this.scenario.environment;
    return `${Math.round(env.temperature)}°C · ${Math.round(env.humidity)}% · ${Math.round(env.illuminance)}lx`;
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.scenario.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.TEXT_PRIMARY)
        Blank()
        Circle({ width: 7, height: 7 }).fill(this.scenario.accent)
      }
      .width('100%')

      Text(this.scenario.description)
        .fontSize(11)
        .fontColor(Palette.TEXT_MUTED)
        .lineHeight(16)
        .height(32)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.environmentLine())
        .fontSize(11)
        .fontColor(Palette.TEXT_SECONDARY)
        .width('100%')

      Row() {
        Text('开始演练')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.scenario.accent)
        Blank()
        Text('→')
          .fontSize(14)
          .fontColor(this.scenario.accent)
      }
      .width('100%')
      .padding({ top: 7, bottom: 7, left: 10, right: 10 })
      .borderRadius(10)
      .backgroundColor('#0B1929')
    }
    .width(196)
    .padding(13)
    .borderRadius(16)
    .backgroundColor(Palette.SURFACE)
    .border({ width: 1, color: '#1B3049' })
    .onClick(() => {
      this.onRun(this.scenario);
    })
  }
}
