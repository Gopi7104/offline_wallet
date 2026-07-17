import { Device } from './device';

/** DeviceRepository — port (ARCHITECTURE.md §5.1). Domain defines the interface; infrastructure implements it. */
export interface DeviceRepository {
  findById(deviceId: string): Promise<Device | null>;
  findByAccountId(accountId: string): Promise<Device[]>;
  save(device: Device): Promise<void>;
  /** Active devices whose lastSeenAt is at or before `cutoff` — candidates for disable-inactive sweeps. */
  findActiveNotSeenSince(cutoff: Date): Promise<Device[]>;
}
