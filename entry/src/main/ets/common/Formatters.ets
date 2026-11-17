import { EnvironmentState } from '../model/Models';

export class Formatters {
  private static pad2(value: number): string {
    if (value < 10) {
      return `0${value}`;
    }
    return `${value}`;
  }

  static clock(timestamp: number): string {
    const date = new Date(timestamp);
    return `${Formatters.pad2(date.getHours())}:${Formatters.pad2(date.getMinutes())}:${Formatters.pad2(date.getSeconds())}`;
  }

  static dateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = Formatters.pad2(date.getMonth() + 1);
    const day = Formatters.pad2(date.getDate());
    return `${month}-${day} ${Formatters.clock(timestamp)}`;
  }

  static environment(environment: EnvironmentState): string {
    return `${Math.round(environment.temperature)}°C · ${Math.round(environment.humidity)}% · ` +
      `${Math.round(environment.illuminance)}lx · ${Math.round(environment.co2)}ppm`;
  }

  static environmentShort(environment: EnvironmentState): string {
    return `${Math.round(environment.temperature)}°C / ${Math.round(environment.humidity)}%RH`;
  }

  static executionOrder(names: string[]): string {
    if (names.length === 0) {
      return '无规则命中';
    }
    const parts: string[] = [];
    for (let i = 0; i < names.length; i++) {
      parts.push(`${i + 1}. ${names[i]}`);
    }
    return parts.join('  ·  ');
  }
}
