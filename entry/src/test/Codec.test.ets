import { describe, expect, it } from '@ohos/hypium';
import { DefaultData } from '../main/ets/data/Defaults';
import {
  AutomationRule,
  CompareOperator,
  EnvironmentState,
  ExecutionRecord,
  EnvMetric,
  PersistedState
} from '../main/ets/model/Models';
import { StateCodec } from '../main/ets/storage/Codec';

function makeLog(index: number): ExecutionRecord {
  const env: EnvironmentState = {
    temperature: 24,
    humidity: 55,
    illuminance: 500,
    co2: 700
  };
  const log: ExecutionRecord = {
    id: `log-${index}`,
    timestamp: 1000 + index,
    scenario: '自动化测试',
    environment: env,
    executedRuleIds: ['r-test'],
    executedRuleNames: ['测试规则'],
    executedConditions: ['测试规则：温度 ≥ 26°C'],
    changes: [],
    conflicts: [],
    summary: '测试日志'
  };
  return log;
}

function makeState(logCount: number): PersistedState {
  const logs: ExecutionRecord[] = [];
  for (let i = 0; i < logCount; i++) {
    logs.push(makeLog(i));
  }
  const state: PersistedState = {
    version: DefaultData.VERSION,
    environment: DefaultData.environment(),
    devices: DefaultData.devices(),
    rules: DefaultData.rules(),
    logs: logs
  };
  return state;
}

export default function codecTest() {
  describe('StateCodecTest', () => {
    it('normal_encode_decode_round_trip', 0, () => {
      const state = makeState(2);
      const decoded = StateCodec.decode(StateCodec.encode(state));
      expect(decoded === null).assertFalse();
      if (decoded !== null) {
        expect(decoded.version).assertEqual(DefaultData.VERSION);
        expect(decoded.devices.length).assertEqual(5);
        expect(decoded.rules.length).assertEqual(7);
        expect(decoded.logs.length).assertEqual(2);
        expect(decoded.environment.temperature).assertEqual(24);
      }
    });

    it('boundary_values_are_clamped', 0, () => {
      const state = makeState(0);
      state.environment.temperature = 99;
      state.environment.humidity = -5;
      state.devices[0].value = 999;
      const decoded = StateCodec.decode(StateCodec.encode(state));
      expect(decoded === null).assertFalse();
      if (decoded !== null) {
        expect(decoded.environment.temperature).assertEqual(40);
        expect(decoded.environment.humidity).assertEqual(0);
        expect(decoded.devices[0].value).assertEqual(100);
      }
    });

    it('boundary_logs_are_trimmed_to_limit', 0, () => {
      const state = makeState(35);
      const decoded = StateCodec.decode(StateCodec.encode(state));
      expect(decoded === null).assertFalse();
      if (decoded !== null) {
        expect(decoded.logs.length).assertEqual(DefaultData.MAX_LOGS);
        expect(decoded.logs[0].id).assertEqual('log-0');
      }
    });

    it('exception_invalid_json_returns_null', 0, () => {
      expect(StateCodec.decode('{not-a-json') === null).assertTrue();
      expect(StateCodec.decode('') === null).assertTrue();
    });

    it('exception_version_mismatch_returns_null', 0, () => {
      const state = makeState(1);
      state.version = 2;
      expect(StateCodec.decode(JSON.stringify(state)) === null).assertTrue();
    });

    it('exception_missing_devices_returns_null', 0, () => {
      const state = makeState(1);
      state.devices = [];
      expect(StateCodec.decode(JSON.stringify(state)) === null).assertTrue();
    });

    it('exception_invalid_rule_is_dropped', 0, () => {
      const state = makeState(1);
      const valid: AutomationRule = {
        id: 'r-valid',
        name: '有效规则',
        enabled: true,
        priority: 20,
        conditions: [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 26 }],
        actions: [{ deviceId: 'device-ac', power: true }],
        revision: 0
      };
      const invalid: AutomationRule = {
        id: 'r-invalid',
        name: '无效规则',
        enabled: true,
        priority: 20,
        conditions: [],
        actions: [{ deviceId: 'device-ac', power: true }],
        revision: 0
      };
      state.rules = [valid, invalid];
      const decoded = StateCodec.decode(StateCodec.encode(state));
      expect(decoded === null).assertFalse();
      if (decoded !== null) {
        expect(decoded.rules.length).assertEqual(1);
        expect(decoded.rules[0].id).assertEqual('r-valid');
      }
    });
  });
}
