import { DefaultData } from '../data/Defaults';
import { EnvMetric, EnvironmentState } from '../model/Models';
import { Palette } from '../theme/Palette';

@Component
export struct EnvironmentPanel {
  @Prop environment: EnvironmentState;
  onMetricChange: (metric: EnvMetric, value: number) => void =
    (metric: EnvMetric, value: number): void => {
    };
  onCommit: () => void = (): void => {
  };

  private metricValue(metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return this.environment.temperature;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return this.environment.humidity;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return this.environment.illuminance;
    }
    return this.environment.co2;
  }

  private metricAccent(metric: EnvMetric): string {
    if (metric === EnvMetric.TEMPERATURE) {
      return '#FF9F6B';
    }
    if (metric === EnvMetric.HUMIDITY) {
      return '#5AC8FA';
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return '#FFD166';
    }
    return '#9C8CFF';
  }

  @Builder
  metricRow(metric: EnvMetric) {
    Column({ space: 2 }) {
      Row() {
        Row({ space: 6 }) {
          Circle({ width: 6, height: 6 }).fill(this.metricAccent(metric))
          Text(DefaultData.metricLabel(metric))
            .fontSize(13)
            .fontColor(Palette.TEXT_SECONDARY)
        }

        Blank()
        Text(`${Math.round(this.metricValue(metric))}${DefaultData.metricUnit(metric)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.TEXT_PRIMARY)
      }
      .width('100%')

      Slider({
        value: this.metricValue(metric),
        min: DefaultData.metricMin(metric),
        max: DefaultData.metricMax(metric),
        step: DefaultData.metricStep(metric),
        style: SliderStyle.OutSet
      })
        .blockColor(this.metricAccent(metric))
        .trackColor('#1B2C44')
        .selectedColor(this.metricAccent(metric))
        .trackThickness(4)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onMetricChange(metric, value);
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.onCommit();
          }
        })
    }
    .width('100%')
    .padding({ top: 6, bottom: 2 })
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('MOCK 环境')
            .fontSize(11)
            .letterSpacing(1.6)
            .fontColor(Palette.ACCENT)
          Text('传感器输入台')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT_PRIMARY)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 5 }) {
          Circle({ width: 6, height: 6 }).fill(Palette.SUCCESS)
          Text('实时模拟')
            .fontSize(11)
            .fontColor(Palette.TEXT_SECONDARY)
        }
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .borderRadius(12)
        .backgroundColor('#12251F')
      }
      .width('100%')

      Text('拖动滑块改变模拟环境，规则引擎按当前数值判断触发条件。')
        .fontSize(11)
        .fontColor(Palette.TEXT_MUTED)
        .width('100%')

      Divider().color(Palette.BORDER).strokeWidth(1)
      this.metricRow(EnvMetric.TEMPERATURE)
      this.metricRow(EnvMetric.HUMIDITY)
      this.metricRow(EnvMetric.ILLUMINANCE)
      this.metricRow(EnvMetric.CO2)
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .backgroundColor(Palette.CARD)
    .border({ width: 1, color: Palette.BORDER })
  }
}
