import { describe, expect, it } from '@ohos/hypium';
import { DefaultData } from '../main/ets/data/Defaults';
import { RuleEngine } from '../main/ets/engine/RuleEngine';
import {
  AutomationRule,
  CompareOperator,
  DeviceState,
  EnvMetric,
  EnvironmentState,
  RuleAction,
  RuleCondition
} from '../main/ets/model/Models';

function environment(temperature: number, humidity: number, illuminance: number, co2: number): EnvironmentState {
  const env: EnvironmentState = {
    temperature: temperature,
    humidity: humidity,
    illuminance: illuminance,
    co2: co2
  };
  return env;
}

function makeRule(id: string, name: string, priority: number, conditions: RuleCondition[],
  actions: RuleAction[], enabled: boolean): AutomationRule {
  const rule: AutomationRule = {
    id: id,
    name: name,
    enabled: enabled,
    priority: priority,
    conditions: conditions,
    actions: actions,
    revision: 0
  };
  return rule;
}

function findDevice(devices: DeviceState[], id: string): DeviceState | null {
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].id === id) {
      return devices[i];
    }
  }
  return null;
}

function lightValueRule(value: number): AutomationRule {
  return makeRule('r-light', '照明测试', 20,
    [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 150 }],
    [{ deviceId: 'device-light', power: true, value: value }], true);
}

export default function ruleEngineTest() {
  describe('RuleEngineTest', () => {
    it('normal_single_condition_triggers_device', 0, () => {
      const rules: AutomationRule[] = [
        makeRule('r-cool', '高温制冷', 30,
          [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 28 }],
          [{ deviceId: 'device-ac', power: true, value: 24 }], true)
      ];
      const result = RuleEngine.run(rules, environment(30, 50, 500, 700), DefaultData.devices());
      expect(result.executedRuleNames.length).assertEqual(1);
      expect(result.executedRuleNames[0]).assertEqual('高温制冷');
      const ac = findDevice(result.devices, 'device-ac');
      expect(ac === null).assertFalse();
      if (ac !== null) {
        expect(ac.power).assertTrue();
        expect(ac.value).assertEqual(24);
      }
      expect(result.summary).assertContain('执行 1 条规则');
    });

    it('normal_two_conditions_require_both_true', 0, () => {
      const rules: AutomationRule[] = [
        makeRule('r-humid-cool', '闷热除湿', 35,
          [
            { metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 26 },
            { metric: EnvMetric.HUMIDITY, operator: CompareOperator.GTE, value: 70 }
          ],
          [{ deviceId: 'device-ac', power: true, value: 25 }], true)
      ];
      const matched = RuleEngine.run(rules, environment(27, 80, 500, 700), DefaultData.devices());
      expect(matched.executedRuleNames.length).assertEqual(1);
      const unmatched = RuleEngine.run(rules, environment(27, 60, 500, 700), DefaultData.devices());
      expect(unmatched.executedRuleNames.length).assertEqual(0);
    });

    it('boundary_threshold_equality', 0, () => {
      const gteRules: AutomationRule[] = [
        makeRule('r-gte', '大于等于', 20,
          [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 28 }],
          [{ deviceId: 'device-ac', power: true }], true)
      ];
      const gteResult = RuleEngine.run(gteRules, environment(28, 50, 500, 700), DefaultData.devices());
      expect(gteResult.executedRuleNames.length).assertEqual(1);
      const gtRules: AutomationRule[] = [
        makeRule('r-gt', '大于', 20,
          [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GT, value: 28 }],
          [{ deviceId: 'device-ac', power: true }], true)
      ];
      const gtResult = RuleEngine.run(gtRules, environment(28, 50, 500, 700), DefaultData.devices());
      expect(gtResult.executedRuleNames.length).assertEqual(0);
    });

    it('boundary_device_value_is_clamped', 0, () => {
      const high = RuleEngine.run([lightValueRule(150)], environment(24, 55, 50, 700), DefaultData.devices());
      const highLight = findDevice(high.devices, 'device-light');
      expect(highLight === null).assertFalse();
      if (highLight !== null) {
        expect(highLight.value).assertEqual(100);
      }
      const low = RuleEngine.run([lightValueRule(-20)], environment(24, 55, 50, 700), DefaultData.devices());
      const lowLight = findDevice(low.devices, 'device-light');
      expect(lowLight === null).assertFalse();
      if (lowLight !== null) {
        expect(lowLight.value).assertEqual(0);
      }
    });

    it('normal_priority_order_resolves_conflict', 0, () => {
      const high: AutomationRule = makeRule('r-high', '深夜护眼', 45,
        [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 60 }],
        [{ deviceId: 'device-light', power: true, value: 25 }], true);
      const low: AutomationRule = makeRule('r-low', '暗光照明', 20,
        [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 150 }],
        [{ deviceId: 'device-light', power: true, value: 60 }], true);
      const result = RuleEngine.run([low, high], environment(24, 55, 30, 700), DefaultData.devices());
      expect(result.executedRuleNames.length).assertEqual(2);
      expect(result.executedRuleNames[0]).assertEqual('深夜护眼');
      expect(result.executedRuleNames[1]).assertEqual('暗光照明');
      expect(result.changes.length).assertEqual(2);
      expect(result.conflicts.length).assertEqual(1);
      expect(result.conflicts[0].keptByRuleName).assertEqual('深夜护眼');
      const light = findDevice(result.devices, 'device-light');
      expect(light === null).assertFalse();
      if (light !== null) {
        expect(light.value).assertEqual(25);
      }
    });

    it('normal_disabled_rule_is_ignored', 0, () => {
      const rules: AutomationRule[] = [
        makeRule('r-off', '停用规则', 20,
          [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 150 }],
          [{ deviceId: 'device-light', power: true }], false)
      ];
      const result = RuleEngine.run(rules, environment(24, 55, 30, 700), DefaultData.devices());
      expect(result.executedRuleNames.length).assertEqual(0);
      expect(result.changes.length).assertEqual(0);
      const light = findDevice(result.devices, 'device-light');
      expect(light === null).assertFalse();
      if (light !== null) {
        expect(light.power).assertFalse();
      }
    });

    it('boundary_empty_rules_keep_devices', 0, () => {
      const result = RuleEngine.run([], environment(30, 80, 30, 1800), DefaultData.devices());
      expect(result.executedRuleNames.length).assertEqual(0);
      expect(result.changes.length).assertEqual(0);
      expect(result.summary).assertContain('未命中');
    });

    it('exception_unknown_device_action_is_ignored', 0, () => {
      const rules: AutomationRule[] = [
        makeRule('r-missing', '未知设备', 20,
          [{ metric: EnvMetric.CO2, operator: CompareOperator.GTE, value: 1200 }],
          [{ deviceId: 'device-not-exist', power: true }], true)
      ];
      const result = RuleEngine.run(rules, environment(24, 55, 500, 1500), DefaultData.devices());
      expect(result.executedRuleNames.length).assertEqual(1);
      expect(result.changes.length).assertEqual(0);
      expect(result.conflicts.length).assertEqual(0);
    });

    it('normal_overlap_detection', 0, () => {
      const first: AutomationRule = makeRule('r-a', '照明A', 30,
        [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 150 }],
        [{ deviceId: 'device-light', power: true, value: 40 }], true);
      const second: AutomationRule = makeRule('r-b', '照明B', 20,
        [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 100 }],
        [{ deviceId: 'device-light', power: true, value: 80 }], true);
      const overlaps = RuleEngine.findOverlaps([first, second], DefaultData.devices());
      expect(overlaps.length).assertEqual(2);
      expect(overlaps[0].deviceName).assertEqual('主灯');
      const text = RuleEngine.overlapTextForRule('r-a', [first, second], DefaultData.devices());
      expect(text).assertContain('照明B');
    });

    it('normal_power_only_humidifier_action', 0, () => {
      const rules: AutomationRule[] = [
        makeRule('r-humidify', '干燥加湿', 25,
          [{ metric: EnvMetric.HUMIDITY, operator: CompareOperator.LT, value: 35 }],
          [{ deviceId: 'device-humidifier', power: true }], true)
      ];
      const result = RuleEngine.run(rules, environment(20, 20, 300, 600), DefaultData.devices());
      expect(result.changes.length).assertEqual(1);
      const humidifier = findDevice(result.devices, 'device-humidifier');
      expect(humidifier === null).assertFalse();
      if (humidifier !== null) {
        expect(humidifier.power).assertTrue();
      }
    });
  });
}
