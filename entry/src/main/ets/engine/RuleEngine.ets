import { DefaultData } from '../data/Defaults';
import {
  AutomationRule,
  CompareOperator,
  ConflictRecord,
  DeviceChange,
  DeviceState,
  EngineResult,
  EnvMetric,
  EnvironmentState,
  RuleAction,
  RuleCondition,
  RuleOverlap,
  cloneDevice
} from '../model/Models';

class FieldLock {
  ruleName: string;
  text: string;

  constructor(ruleName: string, text: string) {
    this.ruleName = ruleName;
    this.text = text;
  }
}

export class RuleEngine {
  static metricValue(environment: EnvironmentState, metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return environment.temperature;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return environment.humidity;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return environment.illuminance;
    }
    return environment.co2;
  }

  static operatorSymbol(operator: CompareOperator): string {
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

  static compare(left: number, operator: CompareOperator, right: number): boolean {
    if (operator === CompareOperator.GT) {
      return left > right;
    }
    if (operator === CompareOperator.GTE) {
      return left >= right;
    }
    if (operator === CompareOperator.LT) {
      return left < right;
    }
    return left <= right;
  }

  static evaluateCondition(environment: EnvironmentState, condition: RuleCondition): boolean {
    const actual = RuleEngine.metricValue(environment, condition.metric);
    return RuleEngine.compare(actual, condition.operator, condition.value);
  }

  static isRuleMatched(rule: AutomationRule, environment: EnvironmentState): boolean {
    if (!rule.enabled || rule.conditions.length === 0) {
      return false;
    }
    for (let i = 0; i < rule.conditions.length; i++) {
      if (!RuleEngine.evaluateCondition(environment, rule.conditions[i])) {
        return false;
      }
    }
    return true;
  }

  static describeCondition(condition: RuleCondition): string {
    const label = DefaultData.metricLabel(condition.metric);
    const unit = DefaultData.metricUnit(condition.metric);
    const symbol = RuleEngine.operatorSymbol(condition.operator);
    return `${label} ${symbol} ${condition.value}${unit}`;
  }

  static describeRuleConditions(rule: AutomationRule): string {
    if (rule.conditions.length === 0) {
      return '未设置条件';
    }
    let text = '';
    for (let i = 0; i < rule.conditions.length; i++) {
      if (i > 0) {
        text += ' 且 ';
      }
      text += RuleEngine.describeCondition(rule.conditions[i]);
    }
    return text;
  }

  static clampValue(value: number, minValue: number, maxValue: number): number {
    const rounded = Math.round(value);
    if (rounded < minValue) {
      return minValue;
    }
    if (rounded > maxValue) {
      return maxValue;
    }
    return rounded;
  }

  static describeAction(action: RuleAction, devices: DeviceState[]): string {
    const device = DefaultData.findDevice(devices, action.deviceId);
    if (device === null) {
      return '未知设备动作';
    }
    const parts: string[] = [];
    if (action.power !== undefined) {
      parts.push(action.power ? '开启' : '关闭');
    }
    if (action.value !== undefined && device.hasValue) {
      const value = RuleEngine.clampValue(action.value, device.minValue, device.maxValue);
      parts.push(`${device.valueLabel} ${value}${device.unit}`);
    }
    if (parts.length === 0) {
      return `${device.name} 保持原状`;
    }
    return `${device.name} ${parts.join(' · ')}`;
  }

  static describeRuleActions(rule: AutomationRule, devices: DeviceState[]): string {
    if (rule.actions.length === 0) {
      return '未设置动作';
    }
    let text = '';
    for (let i = 0; i < rule.actions.length; i++) {
      if (i > 0) {
        text += '；';
      }
      text += RuleEngine.describeAction(rule.actions[i], devices);
    }
    return text;
  }

  static activeRules(rules: AutomationRule[]): AutomationRule[] {
    const active: AutomationRule[] = [];
    for (let i = 0; i < rules.length; i++) {
      if (rules[i].enabled) {
        active.push(rules[i]);
      }
    }
    active.sort((left: AutomationRule, right: AutomationRule): number => {
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
    return active;
  }

  static run(rules: AutomationRule[], environment: EnvironmentState, devices: DeviceState[]): EngineResult {
    const workingDevices: DeviceState[] = [];
    for (let i = 0; i < devices.length; i++) {
      workingDevices.push(cloneDevice(devices[i]));
    }
    const changes: DeviceChange[] = [];
    const conflicts: ConflictRecord[] = [];
    const executedRuleIds: string[] = [];
    const executedRuleNames: string[] = [];
    const matchedConditionTexts: string[] = [];
    const locks = new Map<string, FieldLock>();
    const orderedRules = RuleEngine.activeRules(rules);

    for (let i = 0; i < orderedRules.length; i++) {
      const rule = orderedRules[i];
      if (!RuleEngine.isRuleMatched(rule, environment)) {
        continue;
      }
      executedRuleIds.push(rule.id);
      executedRuleNames.push(rule.name);
      matchedConditionTexts.push(`${rule.name}：${RuleEngine.describeRuleConditions(rule)}`);
      for (let j = 0; j < rule.actions.length; j++) {
        const action = rule.actions[j];
        const device = RuleEngine.findDevice(workingDevices, action.deviceId);
        if (device === null) {
          continue;
        }
        if (action.power !== undefined) {
          const powerKey = `${device.id}:power`;
          const desiredPower = action.power ? '开启' : '关闭';
          const powerLock = locks.get(powerKey);
          if (powerLock !== undefined) {
            if (powerLock.text !== desiredPower) {
              conflicts.push({
                ruleId: rule.id,
                ruleName: rule.name,
                deviceId: device.id,
                deviceName: device.name,
                field: '电源',
                requested: desiredPower,
                keptByRuleName: powerLock.ruleName
              });
            }
          } else {
            locks.set(powerKey, new FieldLock(rule.name, desiredPower));
            if (device.power !== action.power) {
              changes.push({
                deviceId: device.id,
                deviceName: device.name,
                field: '电源',
                fromText: device.power ? '开启' : '关闭',
                toText: desiredPower,
                ruleId: rule.id,
                ruleName: rule.name
              });
              device.power = action.power;
            }
          }
        }
        if (action.value !== undefined && device.hasValue) {
          const valueKey = `${device.id}:value`;
          const clamped = RuleEngine.clampValue(action.value, device.minValue, device.maxValue);
          const desiredValue = `${device.valueLabel} ${clamped}${device.unit}`;
          const valueLock = locks.get(valueKey);
          if (valueLock !== undefined) {
            if (valueLock.text !== desiredValue) {
              conflicts.push({
                ruleId: rule.id,
                ruleName: rule.name,
                deviceId: device.id,
                deviceName: device.name,
                field: device.valueLabel,
                requested: desiredValue,
                keptByRuleName: valueLock.ruleName
              });
            }
          } else {
            locks.set(valueKey, new FieldLock(rule.name, desiredValue));
            if (device.value !== clamped) {
              changes.push({
                deviceId: device.id,
                deviceName: device.name,
                field: device.valueLabel,
                fromText: `${device.value}${device.unit}`,
                toText: `${clamped}${device.unit}`,
                ruleId: rule.id,
                ruleName: rule.name
              });
              device.value = clamped;
            }
          }
        }
      }
    }

    let summary = '';
    if (executedRuleIds.length === 0) {
      summary = '当前环境未命中任何规则，设备保持原状。';
    } else {
      summary = `按优先级执行 ${executedRuleIds.length} 条规则，更新 ${changes.length} 项设备状态`;
      if (conflicts.length > 0) {
        summary += `，按优先级处理 ${conflicts.length} 处控制冲突`;
      }
      summary += '。';
    }
    const result: EngineResult = {
      devices: workingDevices,
      executedRuleIds: executedRuleIds,
      executedRuleNames: executedRuleNames,
      matchedConditionTexts: matchedConditionTexts,
      changes: changes,
      conflicts: conflicts,
      summary: summary
    };
    return result;
  }

  private static findDevice(devices: DeviceState[], deviceId: string): DeviceState | null {
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].id === deviceId) {
        return devices[i];
      }
    }
    return null;
  }

  static findOverlaps(rules: AutomationRule[], devices: DeviceState[]): RuleOverlap[] {
    const overlaps: RuleOverlap[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < rules.length; i++) {
      const left = rules[i];
      if (!left.enabled) {
        continue;
      }
      for (let j = i + 1; j < rules.length; j++) {
        const right = rules[j];
        if (!right.enabled) {
          continue;
        }
        for (let a = 0; a < left.actions.length; a++) {
          for (let b = 0; b < right.actions.length; b++) {
            const leftAction = left.actions[a];
            const rightAction = right.actions[b];
            if (leftAction.deviceId !== rightAction.deviceId) {
              continue;
            }
            const device = DefaultData.findDevice(devices, leftAction.deviceId);
            if (device === null) {
              continue;
            }
            if (leftAction.power !== undefined && rightAction.power !== undefined) {
              RuleEngine.addOverlap(overlaps, seen, left, right, device, '电源');
            }
            if (leftAction.value !== undefined && rightAction.value !== undefined && device.hasValue) {
              RuleEngine.addOverlap(overlaps, seen, left, right, device, device.valueLabel);
            }
          }
        }
      }
    }
    return overlaps;
  }

  private static addOverlap(overlaps: RuleOverlap[], seen: Set<string>, left: AutomationRule,
    right: AutomationRule, device: DeviceState, field: string): void {
    const key = `${left.id}:${right.id}:${device.id}:${field}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    overlaps.push({
      ruleAId: left.id,
      ruleAName: left.name,
      ruleBId: right.id,
      ruleBName: right.name,
      deviceId: device.id,
      deviceName: device.name,
      field: field
    });
  }

  static overlapTextForRule(ruleId: string, rules: AutomationRule[], devices: DeviceState[]): string {
    const overlaps = RuleEngine.findOverlaps(rules, devices);
    const parts: string[] = [];
    for (let i = 0; i < overlaps.length; i++) {
      const item = overlaps[i];
      if (item.ruleAId !== ruleId && item.ruleBId !== ruleId) {
        continue;
      }
      const otherName = item.ruleAId === ruleId ? item.ruleBName : item.ruleAName;
      parts.push(`与「${otherName}」在 ${item.deviceName}·${item.field} 存在潜在重叠`);
    }
    return parts.join('；');
  }
}


