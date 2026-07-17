import { Device } from '../domain/device';
import { DeviceRepository } from '../domain/device_repository';

/** In-memory DeviceRepository — tests only. */
export class InMemoryDeviceRepository implements DeviceRepository {
  private readonly devices = new Map<string, Device>();

  async findById(deviceId: string): Promise<Device | null> {
    return this.devices.get(deviceId) ?? null;
  }

  async findByAccountId(accountId: string): Promise<Device[]> {
    return [...this.devices.values()].filter((d) => d.accountId === accountId);
  }

  async save(device: Device): Promise<void> {
    this.devices.set(device.deviceId, device);
  }

  async findActiveNotSeenSince(cutoff: Date): Promise<Device[]> {
    return [...this.devices.values()].filter((d) => d.active && d.lastSeenAt.getTime() <= cutoff.getTime());
  }
}
