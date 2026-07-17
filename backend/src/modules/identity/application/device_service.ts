import { Device, DevicePlatform, VALID_DEVICE_PLATFORMS } from '../domain/device';
import { DeviceRepository } from '../domain/device_repository';
import { InvalidDevicePlatform, InvalidDevicePublicKey, DeviceNotFound, DeviceOwnershipConflict } from '../domain/errors';

/** Ed25519 public key: 32 bytes, hex-encoded. */
const PUBLIC_KEY_HEX_PATTERN = /^[0-9a-fA-F]{64}$/;

/**
 * DeviceService — Device Registration use cases (Identity & Device context,
 * production hardening §1). Register / update-last-seen / disable-inactive.
 * Scope note: this is an operational device inventory, not the cryptographic
 * device-binding feature (FR-ID-02/03/04) — see domain/device.ts.
 */
export class DeviceService {
  constructor(
    private readonly repository: DeviceRepository,
    private readonly clock: () => Date = () => new Date(),
  ) {}

  /**
   * Register a device for an account. Idempotent on `deviceId` FOR THE SAME
   * ACCOUNT: re-registering (e.g. app reinstall) refreshes the recorded
   * details, reactivates the device if it had been disabled, and keeps the
   * original registration time. A `deviceId` already owned by a DIFFERENT
   * account is rejected rather than silently reassigned — otherwise any
   * authenticated caller who learns/guesses another account's deviceId could
   * overwrite that record's accountId and evict it from its owner's device
   * list.
   */
  async register(
    accountId: string,
    deviceId: string,
    platform: string,
    deviceModel: string,
    appVersion: string,
    publicKeyHex: string,
  ): Promise<Device> {
    if (!VALID_DEVICE_PLATFORMS.has(platform as DevicePlatform)) {
      throw new InvalidDevicePlatform(platform);
    }
    if (!PUBLIC_KEY_HEX_PATTERN.test(publicKeyHex)) {
      throw new InvalidDevicePublicKey();
    }
    const now = this.clock();
    const existing = await this.repository.findById(deviceId);
    if (existing && existing.accountId !== accountId) {
      throw new DeviceOwnershipConflict(deviceId);
    }
    const device = existing
      ? existing.reregister(accountId, platform as DevicePlatform, deviceModel, appVersion, now, publicKeyHex)
      : Device.register(deviceId, accountId, platform as DevicePlatform, deviceModel, appVersion, now, publicKeyHex);
    await this.repository.save(device);
    return device;
  }

  /** Update a device's last-seen timestamp. Scoped to the calling account — a device owned by someone else is reported as not found. */
  async updateLastSeen(accountId: string, deviceId: string): Promise<Device> {
    const device = await this.repository.findById(deviceId);
    if (!device || device.accountId !== accountId) {
      throw new DeviceNotFound(deviceId);
    }
    const updated = device.withLastSeen(this.clock());
    await this.repository.save(updated);
    return updated;
  }

  async listByAccount(accountId: string): Promise<Device[]> {
    return this.repository.findByAccountId(accountId);
  }

  /**
   * Disable every active device not seen within `inactivityThresholdMs`.
   * A system-wide maintenance sweep (not scoped to one account) — intended
   * for an operational/cron caller, not exposed over the public HTTP API
   * (there is no admin/ops auth tier in this prototype to gate it safely).
   */
  async disableInactiveDevices(inactivityThresholdMs: number): Promise<Device[]> {
    const now = this.clock();
    const cutoff = new Date(now.getTime() - inactivityThresholdMs);
    const stale = await this.repository.findActiveNotSeenSince(cutoff);
    const disabled = stale.map((d) => d.disable());
    for (const device of disabled) {
      await this.repository.save(device);
    }
    return disabled;
  }
}
