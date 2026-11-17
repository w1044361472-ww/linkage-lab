import { Formatters } from '../common/Formatters';
import { ConflictRecord, DeviceChange, ExecutionRecord } from '../model/Models';
import { Palette } from '../theme/Palette';

@Component
export struct LogCard {
  @Prop record: ExecutionRecord;

  @Builder
  changeRow(change: DeviceChange) {
    Row({ space: 7 }) {
      Rect({ width: 3, height: 14, radius: 2 }).fill(Palette.SUCCESS)
      Text(`${change.deviceName} · ${change.field}`)
        .fontSize(11)
        .fontColor(Palette.TEXT_SECONDARY)
      Text(`${change.fromText} → ${change.toText}`)
        .fontSize(11)
        .fontColor(Palette.TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  @Builder
  conflictRow(conflict: ConflictRecord) {
    Row({ space: 7 }) {
      Rect({ width: 3, height: 14, radius: 2 }).fill(Palette.WARNING)
      Text(`${conflict.deviceName} · ${conflict.field}`)
        .fontSize(11)
        .fontColor(Palette.WARNING)
      Text(`「${conflict.ruleName}」请求 ${conflict.requested}，保持「${conflict.keptByRuleName}」`)
        .fontSize(10)
        .fontColor('#D7B27A')
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  build() {
    Column({ space: 9 }) {
      Row() {
        Text(this.record.scenario)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.ACCENT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
          .backgroundColor(Palette.ACCENT_SOFT)
        Blank()
        Text(Formatters.dateTime(this.record.timestamp))
          .fontSize(10)
          .fontColor(Palette.TEXT_MUTED)
      }
      .width('100%')

      Text(Formatters.environment(this.record.environment))
        .fontSize(10)
        .fontColor(Palette.TEXT_MUTED)
        .width('100%')

      Text(Formatters.executionOrder(this.record.executedRuleNames))
        .fontSize(11)
        .fontColor(Palette.TEXT_SECONDARY)
        .lineHeight(17)
        .width('100%')

      if (this.record.executedConditions.length > 0) {
        Column({ space: 3 }) {
          ForEach(this.record.executedConditions, (condition: string, index: number) => {
            Text(condition)
              .fontSize(10)
              .fontColor('#7FB8D6')
              .lineHeight(15)
              .width('100%')
          }, (condition: string, index: number) => `${this.record.id}-condition-${index}`)
        }
        .width('100%')
        .padding({ left: 9, right: 9, top: 7, bottom: 7 })
        .borderRadius(9)
        .backgroundColor('#0A1725')
      }

      if (this.record.changes.length > 0) {
        Column({ space: 5 }) {
          ForEach(this.record.changes, (change: DeviceChange, index: number) => {
            this.changeRow(change)
          }, (change: DeviceChange, index: number) => `${this.record.id}-change-${index}`)
        }
        .width('100%')
        .padding(9)
        .borderRadius(10)
        .backgroundColor('#0B1A19')
      }

      if (this.record.conflicts.length > 0) {
        Column({ space: 5 }) {
          ForEach(this.record.conflicts, (conflict: ConflictRecord, index: number) => {
            this.conflictRow(conflict)
          }, (conflict: ConflictRecord, index: number) => `${this.record.id}-conflict-${index}`)
        }
        .width('100%')
        .padding(9)
        .borderRadius(10)
        .backgroundColor('#241C10')
      }

      Text(this.record.summary)
        .fontSize(10)
        .fontColor(Palette.TEXT_MUTED)
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(16)
    .backgroundColor(Palette.CARD)
    .border({ width: 1, color: Palette.BORDER })
  }
}
