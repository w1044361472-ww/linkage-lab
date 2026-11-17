import {
  AutomationRule,
  CompareOperator,
  DeviceKind,
  DeviceState,
  EnvMetric,
  EnvironmentState,
  RuleAction,
  RuleCondition,
  ScenarioPreset
} from '../model/Models';

export class DefaultData {
  static readonly VERSION: number = 1;
  static readonly MAX_LOGS: number = 30;
  static readonly MAX_RULES: number = 50;
  static readonly MIN_PRIORITY: number = 1;
  static readonly MAX_PRIORITY: number = 99;

  static environment(): EnvironmentState {
    const env: EnvironmentState = {
      temperature: 24,
      humidity: 55,
      illuminance: 520,
      co2: 700
    };
    return env;
  }

  static devices(): DeviceState[] {
    return [
      {
        id: 'device-light',
        name: '主灯',
        kind: DeviceKind.LIGHT,
        power: false,
        value: 55,
        minValue: 0,
        maxValue: 100,
        hasPower: true,
        hasValue: true,
        valueLabel: '亮度',
        unit: '%',
        accent: '#FFC96B',
        shortName: '灯'
      },
      {
        id: 'device-ac',
        name: '空调',
        kind: DeviceKind.AC,
        power: false,
        value: 26,
        minValue: 16,
        maxValue: 30,
        hasPower: true,
        hasValue: true,
        valueLabel: '目标温度',
        unit: '°C',
        accent: '#5AC8FA',
        shortName: '空'
      },
      {
        id: 'device-curtain',
        name: '窗帘',
        kind: DeviceKind.CURTAIN,
        power: true,
        value: 100,
        minValue: 0,
        maxValue: 100,
        hasPower: false,
        hasValue: true,
        valueLabel: '开合度',
        unit: '%',
        accent: '#B58CFF',
        shortName: '帘'
      },
      {
        id: 'device-humidifier',
        name: '加湿器',
        kind: DeviceKind.HUMIDIFIER,
        power: false,
        value: 50,
        minValue: 0,
        maxValue: 100,
        hasPower: true,
        hasValue: false,
        valueLabel: '',
        unit: '%',
        accent: '#4FE3C1',
        shortName: '湿'
      },
      {
        id: 'device-purifier',
        name: '净化器',
        kind: DeviceKind.PURIFIER,
        power: false,
        value: 2,
        minValue: 1,
        maxValue: 3,
        hasPower: true,
        hasValue: true,
        valueLabel: '风速',
        unit: '档',
        accent: '#8BE28B',
        shortName: '净'
      }
    ];
  }

  static rules(): AutomationRule[] {
    return [
      {
        id: 'rule-night-light',
        name: '深夜护眼',
        enabled: true,
        priority: 45,
        conditions: [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 60 }],
        actions: [{ deviceId: 'device-light', power: true, value: 25 }],
        revision: 0
      },
      {
        id: 'rule-sunshade',
        name: '高温遮阳',
        enabled: true,
        priority: 50,
        conditions: [
          { metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 30 },
          { metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.GTE, value: 1200 }
        ],
        actions: [{ deviceId: 'device-curtain', value: 20 }],
        revision: 0
      },
      {
        id: 'rule-humid-cool',
        name: '闷热除湿',
        enabled: true,
        priority: 35,
        conditions: [
          { metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 26 },
          { metric: EnvMetric.HUMIDITY, operator: CompareOperator.GTE, value: 70 }
        ],
        actions: [{ deviceId: 'device-ac', power: true, value: 25 }],
        revision: 0
      },
      {
        id: 'rule-ac-cool',
        name: '高温制冷',
        enabled: true,
        priority: 30,
        conditions: [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 28 }],
        actions: [{ deviceId: 'device-ac', power: true, value: 24 }],
        revision: 0
      },
      {
        id: 'rule-humidify',
        name: '干燥加湿',
        enabled: true,
        priority: 25,
        conditions: [{ metric: EnvMetric.HUMIDITY, operator: CompareOperator.LT, value: 35 }],
        actions: [{ deviceId: 'device-humidifier', power: true }],
        revision: 0
      },
      {
        id: 'rule-soft-light',
        name: '暗光照明',
        enabled: true,
        priority: 20,
        conditions: [{ metric: EnvMetric.ILLUMINANCE, operator: CompareOperator.LT, value: 150 }],
        actions: [{ deviceId: 'device-light', power: true, value: 60 }],
        revision: 0
      },
      {
        id: 'rule-purify',
        name: '空气净化',
        enabled: true,
        priority: 15,
        conditions: [{ metric: EnvMetric.CO2, operator: CompareOperator.GTE, value: 1200 }],
        actions: [{ deviceId: 'device-purifier', power: true, value: 2 }],
        revision: 0
      }
    ];
  }

  static scenarios(): ScenarioPreset[] {
    return [
      {
        id: 'scenario-summer-night',
        name: '夏夜闷热',
        description: '高温高湿且光线昏暗，验证除湿与照明的控制顺序。',
        environment: { temperature: 29, humidity: 78, illuminance: 40, co2: 900 },
        accent: '#FF9F6B'
      },
      {
        id: 'scenario-morning-sun',
        name: '清晨强光',
        description: '强日照叠加高温，观察遮阳与制冷联动。',
        environment: { temperature: 31, humidity: 46, illuminance: 1600, co2: 620 },
        accent: '#FFD166'
      },
      {
        id: 'scenario-winter-dry',
        name: '冬日干燥',
        description: '低湿环境触发加湿器，保持宿舍舒适度。',
        environment: { temperature: 17, humidity: 26, illuminance: 320, co2: 560 },
        accent: '#6CD6FF'
      },
      {
        id: 'scenario-study-return',
        name: '自习归来',
        description: '低光与高二氧化碳同时出现，验证多规则协同。',
        environment: { temperature: 27, humidity: 62, illuminance: 120, co2: 1450 },
        accent: '#9C8CFF'
      }
    ];
  }

  static blankRule(id: string): AutomationRule {
    const rule: AutomationRule = {
      id: id,
      name: '新规则',
      enabled: true,
      priority: 20,
      conditions: [{ metric: EnvMetric.TEMPERATURE, operator: CompareOperator.GTE, value: 26 }],
      actions: [{ deviceId: 'device-ac', power: true, value: 25 }],
      revision: 0
    };
    return rule;
  }

  static defaultMetricValue(metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return 26;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return 60;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return 200;
    }
    return 1000;
  }

  static metricLabel(metric: EnvMetric): string {
    if (metric === EnvMetric.TEMPERATURE) {
      return '温度';
    }
    if (metric === EnvMetric.HUMIDITY) {
      return '湿度';
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return '光照';
    }
    return 'CO₂';
  }

  static metricUnit(metric: EnvMetric): string {
    if (metric === EnvMetric.TEMPERATURE) {
      return '°C';
    }
    if (metric === EnvMetric.HUMIDITY) {
      return '%';
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return 'lx';
    }
    return 'ppm';
  }

  static metricMin(metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return 0;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return 0;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return 0;
    }
    return 400;
  }

  static metricMax(metric: EnvMetric): number {
    if (metric === EnvMetric.TEMPERATURE) {
      return 40;
    }
    if (metric === EnvMetric.HUMIDITY) {
      return 100;
    }
    if (metric === EnvMetric.ILLUMINANCE) {
      return 2000;
    }
    return 2000;
  }

  static metricStep(metric: EnvMetric): number {
    if (metric === EnvMetric.ILLUMINANCE || metric === EnvMetric.CO2) {
      return 10;
    }
    return 1;
  }

  static newRuleAction(device: DeviceState): RuleAction {
    const action: RuleAction = { deviceId: device.id };
    if (device.hasPower) {
      action.power = true;
    }
    if (device.hasValue) {
      action.value = device.value;
    }
    return action;
  }

  static findDevice(devices: DeviceState[], deviceId: string): DeviceState | null {
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].id === deviceId) {
        return devices[i];
      }
    }
    return null;
  }

  static newCondition(metric: EnvMetric): RuleCondition {
    const condition: RuleCondition = {
      metric: metric,
      operator: CompareOperator.GTE,
      value: DefaultData.defaultMetricValue(metric)
    };
    return condition;
  }
}
