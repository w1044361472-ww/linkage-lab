import { DefaultData } from '../data/Defaults';
import {
  AutomationRule,
  CompareOperator,
  ConflictRecord,
  DeviceChange,
  DeviceKind,
  DeviceState,
  EnvMetric,
  EnvironmentState,
  ExecutionRecord,
  PersistedState,
  RuleAction,
  RuleCondition
} from '../model/Models';

export class StateCodec {
  static encode(state: PersistedState): string {
    return JSON.stringify(state);
  }

  static decode(raw: string): PersistedState | null {
    if (raw.length < 2) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as PersistedState;
      return StateCodec.normalize(parsed);
    } catch (error) {
      return null;
    }
  }

  static normalize(input: PersistedState): PersistedState | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (input.version !== DefaultData.VERSION) {
      return null;
    }
    if (input.environment === null || input.environment === undefined) {
      return null;
    }
    if (!Array.isArray(input.devices) || input.devices.length === 0) {
      return null;
    }
    if (!Array.isArray(input.rules) || !Array.isArray(input.logs)) {
      return null;
    }
    const environment = StateCodec.normalizeEnvironment(input.environment);
    const devices: DeviceState[] = [];
    for (let i = 0; i < input.devices.length; i++) {
      const device = StateCodec.normalizeDevice(input.devices[i]);
      if (device !== null) {
        devices.push(device);
      }
    }
    if (devices.length === 0) {
      return null;
    }
    const rules: AutomationRule[] = [];
    for (let i = 0; i < input.rules.length && rules.length < DefaultData.MAX_RULES; i++) {
      const rule = StateCodec.normalizeRule(input.rules[i]);
      if (rule !== null) {
        rules.push(rule);
      }
    }
    const logs: ExecutionRecord[] = [];
    for (let i = 0; i < input.logs.length && logs.length < DefaultData.MAX_LOGS; i++) {
      const log = StateCodec.normalizeLog(input.logs[i]);
      if (log !== null) {
        logs.push(log);
      }
    }
    const state: PersistedState = {
      version: DefaultData.VERSION,
      environment: environment,
      devices: devices,
      rules: rules,
      logs: logs
    };
    return state;
  }

  private static normalizeEnvironment(input: EnvironmentState): EnvironmentState {
    const defaults = DefaultData.environment();
    const environment: EnvironmentState = {
      temperature: StateCodec.clampNumber(input.temperature, defaults.temperature, 0, 40),
      humidity: StateCodec.clampNumber(input.humidity, defaults.humidity, 0, 100),
      illuminance: StateCodec.clampNumber(input.illuminance, defaults.illuminance, 0, 2000),
      co2: StateCodec.clampNumber(input.co2, defaults.co2, 400, 2000)
    };
    return environment;
  }

  private static normalizeDevice(input: DeviceState): DeviceState | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.id !== 'string' || input.id.length === 0) {
      return null;
    }
    if (typeof input.name !== 'string' || input.name.length === 0) {
      return null;
    }
    if (!StateCodec.isDeviceKind(input.kind)) {
      return null;
    }
    const minValue = StateCodec.clampNumber(input.minValue, 0, -10000, 10000);
    const maxValue = StateCodec.clampNumber(input.maxValue, 100, -10000, 10000);
    const safeMin = minValue <= maxValue ? minValue : maxValue;
    const safeMax = minValue <= maxValue ? maxValue : minValue;
    const value = StateCodec.clampNumber(input.value, safeMin, safeMin, safeMax);
    const device: DeviceState = {
      id: input.id,
      name: input.name,
      kind: input.kind,
      power: input.power === true,
      value: value,
      minValue: safeMin,
      maxValue: safeMax,
      hasPower: input.hasPower === true,
      hasValue: input.hasValue === true,
      valueLabel: typeof input.valueLabel === 'string' ? input.valueLabel : '',
      unit: typeof input.unit === 'string' ? input.unit : '',
      accent: typeof input.accent === 'string' ? input.accent : '#5AC8FA',
      shortName: typeof input.shortName === 'string' ? input.shortName : input.name.substring(0, 1)
    };
    return device;
  }

  private static normalizeRule(input: AutomationRule): AutomationRule | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.id !== 'string' || input.id.length === 0) {
      return null;
    }
    if (typeof input.name !== 'string' || input.name.length === 0) {
      return null;
    }
    if (!Array.isArray(input.conditions) || input.conditions.length === 0 || input.conditions.length > 2) {
      return null;
    }
    if (!Array.isArray(input.actions) || input.actions.length === 0 || input.actions.length > 3) {
      return null;
    }
    const conditions: RuleCondition[] = [];
    for (let i = 0; i < input.conditions.length; i++) {
      const condition = StateCodec.normalizeCondition(input.conditions[i]);
      if (condition === null) {
        return null;
      }
      conditions.push(condition);
    }
    const actions: RuleAction[] = [];
    for (let i = 0; i < input.actions.length; i++) {
      const action = StateCodec.normalizeAction(input.actions[i]);
      if (action === null) {
        return null;
      }
      actions.push(action);
    }
    const priority = StateCodec.clampNumber(input.priority, 20,
      DefaultData.MIN_PRIORITY, DefaultData.MAX_PRIORITY);
    const revision = StateCodec.clampNumber(input.revision, 0, 0, 1000000);
    const rule: AutomationRule = {
      id: input.id,
      name: input.name,
      enabled: input.enabled === true,
      priority: priority,
      conditions: conditions,
      actions: actions,
      revision: revision
    };
    return rule;
  }

  private static normalizeCondition(input: RuleCondition): RuleCondition | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (!StateCodec.isMetric(input.metric)) {
      return null;
    }
    if (!StateCodec.isOperator(input.operator)) {
      return null;
    }
    const min = DefaultData.metricMin(input.metric);
    const max = DefaultData.metricMax(input.metric);
    const condition: RuleCondition = {
      metric: input.metric,
      operator: input.operator,
      value: StateCodec.clampNumber(input.value, DefaultData.defaultMetricValue(input.metric), min, max)
    };
    return condition;
  }

  private static normalizeAction(input: RuleAction): RuleAction | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.deviceId !== 'string' || input.deviceId.length === 0) {
      return null;
    }
    const action: RuleAction = { deviceId: input.deviceId };
    if (typeof input.power === 'boolean') {
      action.power = input.power;
    }
    if (typeof input.value === 'number' && Number.isFinite(input.value)) {
      action.value = input.value;
    }
    if (action.power === undefined && action.value === undefined) {
      return null;
    }
    return action;
  }

  private static normalizeLog(input: ExecutionRecord): ExecutionRecord | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.id !== 'string' || input.id.length === 0) {
      return null;
    }
    if (typeof input.timestamp !== 'number' || !Number.isFinite(input.timestamp)) {
      return null;
    }
    if (input.environment === null || input.environment === undefined) {
      return null;
    }
    if (!Array.isArray(input.executedRuleIds) || !Array.isArray(input.executedRuleNames)) {
      return null;
    }
    if (!Array.isArray(input.changes) || !Array.isArray(input.conflicts)) {
      return null;
    }
    const environment = StateCodec.normalizeEnvironment(input.environment);
    const executedRuleIds: string[] = [];
    for (let i = 0; i < input.executedRuleIds.length; i++) {
      if (typeof input.executedRuleIds[i] === 'string') {
        executedRuleIds.push(input.executedRuleIds[i]);
      }
    }
    const executedRuleNames: string[] = [];
    for (let i = 0; i < input.executedRuleNames.length; i++) {
      if (typeof input.executedRuleNames[i] === 'string') {
        executedRuleNames.push(input.executedRuleNames[i]);
      }
    }
    const executedConditions: string[] = [];
    if (Array.isArray(input.executedConditions)) {
      for (let i = 0; i < input.executedConditions.length; i++) {
        if (typeof input.executedConditions[i] === 'string') {
          executedConditions.push(input.executedConditions[i]);
        }
      }
    }
    const changes: DeviceChange[] = [];
    for (let i = 0; i < input.changes.length; i++) {
      const change = StateCodec.normalizeChange(input.changes[i]);
      if (change !== null) {
        changes.push(change);
      }
    }
    const conflicts: ConflictRecord[] = [];
    for (let i = 0; i < input.conflicts.length; i++) {
      const conflict = StateCodec.normalizeConflict(input.conflicts[i]);
      if (conflict !== null) {
        conflicts.push(conflict);
      }
    }
    const log: ExecutionRecord = {
      id: input.id,
      timestamp: input.timestamp,
      scenario: typeof input.scenario === 'string' ? input.scenario : '手动执行',
      environment: environment,
      executedRuleIds: executedRuleIds,
      executedRuleNames: executedRuleNames,
      executedConditions: executedConditions,
      changes: changes,
      conflicts: conflicts,
      summary: typeof input.summary === 'string' ? input.summary : ''
    };
    return log;
  }

  private static normalizeChange(input: DeviceChange): DeviceChange | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.deviceId !== 'string' || typeof input.deviceName !== 'string' ||
      typeof input.field !== 'string' || typeof input.fromText !== 'string' ||
      typeof input.toText !== 'string' || typeof input.ruleId !== 'string' ||
      typeof input.ruleName !== 'string') {
      return null;
    }
    const change: DeviceChange = {
      deviceId: input.deviceId,
      deviceName: input.deviceName,
      field: input.field,
      fromText: input.fromText,
      toText: input.toText,
      ruleId: input.ruleId,
      ruleName: input.ruleName
    };
    return change;
  }

  private static normalizeConflict(input: ConflictRecord): ConflictRecord | null {
    if (input === null || input === undefined) {
      return null;
    }
    if (typeof input.ruleId !== 'string' || typeof input.ruleName !== 'string' ||
      typeof input.deviceId !== 'string' || typeof input.deviceName !== 'string' ||
      typeof input.field !== 'string' || typeof input.requested !== 'string' ||
      typeof input.keptByRuleName !== 'string') {
      return null;
    }
    const conflict: ConflictRecord = {
      ruleId: input.ruleId,
      ruleName: input.ruleName,
      deviceId: input.deviceId,
      deviceName: input.deviceName,
      field: input.field,
      requested: input.requested,
      keptByRuleName: input.keptByRuleName
    };
    return conflict;
  }

  private static clampNumber(value: number, fallback: number, min: number, max: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return fallback;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  private static isDeviceKind(value: DeviceKind): boolean {
    return value === DeviceKind.LIGHT || value === DeviceKind.AC || value === DeviceKind.CURTAIN ||
      value === DeviceKind.HUMIDIFIER || value === DeviceKind.PURIFIER;
  }

  private static isMetric(value: EnvMetric): boolean {
    return value === EnvMetric.TEMPERATURE || value === EnvMetric.HUMIDITY ||
      value === EnvMetric.ILLUMINANCE || value === EnvMetric.CO2;
  }

  private static isOperator(value: CompareOperator): boolean {
    return value === CompareOperator.GT || value === CompareOperator.GTE ||
      value === CompareOperator.LT || value === CompareOperator.LTE;
  }
}
