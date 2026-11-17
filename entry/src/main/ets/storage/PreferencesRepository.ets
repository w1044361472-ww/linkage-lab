import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PersistedState } from '../model/Models';
import { StateCodec } from './Codec';

export class PreferencesRepository {
  private static instance: PreferencesRepository | null = null;
  private static readonly STORE_NAME: string = 'linkage_lab_store';
  private static readonly STATE_KEY: string = 'lab_state_v1';
  private store: preferences.Preferences | null = null;

  private constructor() {
  }

  static getInstance(): PreferencesRepository {
    if (PreferencesRepository.instance === null) {
      PreferencesRepository.instance = new PreferencesRepository();
    }
    return PreferencesRepository.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== null) {
      return;
    }
    const options: preferences.Options = { name: PreferencesRepository.STORE_NAME };
    this.store = await preferences.getPreferences(context, options);
  }

  isReady(): boolean {
    return this.store !== null;
  }

  async load(): Promise<PersistedState | null> {
    if (this.store === null) {
      return null;
    }
    const raw = await this.store.get(PreferencesRepository.STATE_KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return null;
    }
    return StateCodec.decode(raw);
  }

  async save(state: PersistedState): Promise<void> {
    if (this.store === null) {
      return;
    }
    const encoded = StateCodec.encode(state);
    await this.store.put(PreferencesRepository.STATE_KEY, encoded);
    await this.store.flush();
  }

  async clear(): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.store.delete(PreferencesRepository.STATE_KEY);
    await this.store.flush();
  }
}
