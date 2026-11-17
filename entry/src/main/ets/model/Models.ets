export enum EnvMetric {
  TEMPERATURE = 'temperature',
  HUMIDITY = 'humidity',
  ILLUMINANCE = 'illuminance',
  CO2 = 'co2'
}

export enum CompareOperator {
  GT = 'gt',
  GTE = 'gte',
  LT = 'lt',
  LTE = 'lte'
}

export enum DeviceKind {
  LIGHT = 'light',
  AC = 'ac',
  CURTAIN = 'curtain',
  HUMIDIFIER = 'humidifier',
  PURIFIER = 'purifier'
}

export interface EnvironmentState {
  temperature: number;
  humidity: number;
  illuminance: number;
  co2: number;
}

export interface DeviceState {
  id: string;
  name: string;
  kind: DeviceKind;
  power: boolean;
  value: number;
  minValue: number;
  maxValue: number;
  hasPower: boolean;
  hasValue: boolean;
  valueLabel: string;
  unit: string;
  accent: string;
  shortName: string;
}

export interface RuleCondition {
  metric: EnvMetric;
  operator: CompareOperator;
  value: number;
}

export interface RuleAction {
  deviceId: string;
  power?: boolean;
  value?: number;
}

export interface AutomationRule {
  id: string;
  name: string;
  enabled: boolean;
  priority: number;
  conditions: RuleCondition[];
  actions: RuleAction[];
  revision: number;
}

export interface DeviceChange {
  deviceId: string;
  deviceName: string;
  field: string;
  fromText: string;
  toText: string;
  ruleId: string;
  ruleName: string;
}

export interface ConflictRecord {
  ruleId: string;
  ruleName: string;
  deviceId: string;
  deviceName: string;
  field: string;
  requested: string;
  keptByRuleName: string;
}

export interface ExecutionRecord {
  id: string;
  timestamp: number;
  scenario: string;
  environment: EnvironmentState;
  executedRuleIds: string[];
  executedRuleNames: string[];
  executedConditions: string[];
  changes: DeviceChange[];
  conflicts: ConflictRecord[];
  summary: string;
}

export interface PersistedState {
  version: number;
  environment: EnvironmentState;
  devices: DeviceState[];
  rules: AutomationRule[];
  logs: ExecutionRecord[];
}

export interface EngineResult {
  devices: DeviceState[];
  executedRuleIds: string[];
  executedRuleNames: string[];
  matchedConditionTexts: string[];
  changes: DeviceChange[];
  conflicts: ConflictRecord[];
  summary: string;
}

export interface ScenarioPreset {
  id: string;
  name: string;
  description: string;
  environment: EnvironmentState;
  accent: string;
}

export interface RuleOverlap {
  ruleAId: string;
  ruleAName: string;
  ruleBId: string;
  ruleBName: string;
  deviceId: string;
  deviceName: string;
  field: string;
}

export function cloneEnvironment(source: EnvironmentState): EnvironmentState {
  const copy: EnvironmentState = {
    temperature: source.temperature,
    humidity: source.humidity,
    illuminance: source.illuminance,
    co2: source.co2
  };
  return copy;
}

export function cloneDevice(source: DeviceState): DeviceState {
  const copy: DeviceState = {
    id: source.id,
    name: source.name,
    kind: source.kind,
    power: source.power,
    value: source.value,
    minValue: source.minValue,
    maxValue: source.maxValue,
    hasPower: source.hasPower,
    hasValue: source.hasValue,
    valueLabel: source.valueLabel,
    unit: source.unit,
    accent: source.accent,
    shortName: source.shortName
  };
  return copy;
}

export function cloneCondition(source: RuleCondition): RuleCondition {
  const copy: RuleCondition = {
    metric: source.metric,
    operator: source.operator,
    value: source.value
  };
  return copy;
}

export function cloneAction(source: RuleAction): RuleAction {
  const copy: RuleAction = { deviceId: source.deviceId };
  if (source.power !== undefined) {
    copy.power = source.power;
  }
  if (source.value !== undefined) {
    copy.value = source.value;
  }
  return copy;
}

export function cloneRule(source: AutomationRule): AutomationRule {
  const conditions: RuleCondition[] = [];
  for (let i = 0; i < source.conditions.length; i++) {
    conditions.push(cloneCondition(source.conditions[i]));
  }
  const actions: RuleAction[] = [];
  for (let i = 0; i < source.actions.length; i++) {
    actions.push(cloneAction(source.actions[i]));
  }
  const copy: AutomationRule = {
    id: source.id,
    name: source.name,
    enabled: source.enabled,
    priority: source.priority,
    conditions: conditions,
    actions: actions,
    revision: source.revision
  };
  return copy;
}

export function cloneDevices(source: DeviceState[]): DeviceState[] {
  const list: DeviceState[] = [];
  for (let i = 0; i < source.length; i++) {
    list.push(cloneDevice(source[i]));
  }
  return list;
}

export function cloneRules(source: AutomationRule[]): AutomationRule[] {
  const list: AutomationRule[] = [];
  for (let i = 0; i < source.length; i++) {
    list.push(cloneRule(source[i]));
  }
  return list;
}

export function cloneLogs(source: ExecutionRecord[]): ExecutionRecord[] {
  const list: ExecutionRecord[] = [];
  for (let i = 0; i < source.length; i++) {
    list.push(source[i]);
  }
  return list;
}


