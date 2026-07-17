/**
 * Device — a registered device inventory record (Identity & Device context,
 * production hardening §1). Deliberately NOT the full cryptographic device
 * binding described in ARCHITECTURE.md §5.2 (`devices`: public_key,
 * attestation, op_counter_seen, one-active-device enforcement — FR-ID-02/03/04,
 * still `#[ ]` in docs/TODO.md "Blocking — Before Final Demo/Release"). This is
 * the simpler operational inventory this hardening task asks for: which
 * devices exist, what they are, and when they were last seen. Multiple active
 * devices per account are allowed here; that is intentionally unlike the
 * future one-active-device feature. Immutable.
 */
export type DevicePlatform = 'android' | 'ios' | 'web';

export const VALID_DEVICE_PLATFORMS: ReadonlySet<DevicePlatform> = new Set(['android', 'ios', 'web']);

export class Device {
  constructor(
    readonly deviceId: string,
    readonly accountId: string,
    readonly platform: DevicePlatform,
    readonly deviceModel: string,
    readonly appVersion: string,
    readonly registeredAt: Date,
    readonly lastSeenAt: Date,
    readonly active: boolean,
    /**
     * The device's Ed25519 public key (hex, 64 chars) — proves ownership of
     * offline transfers signed with the matching private key (FR-PAY-04).
     * Null for rows that predate this field (none in practice: it is required
     * at the HTTP boundary going forward).
     */
    readonly publicKeyHex: string | null = null,
  ) {}

  static register(
    deviceId: string,
    accountId: string,
    platform: DevicePlatform,
    deviceModel: string,
    appVersion: string,
    now: Date,
    publicKeyHex: string,
  ): Device {
    return new Device(deviceId, accountId, platform, deviceModel, appVersion, now, now, true, publicKeyHex);
  }

  /**
   * Re-registration (e.g. app reinstall) refreshes details and reactivates,
   * keeping the original registeredAt. Carries the newly-presented public
   * key — a fresh install generates a fresh device key, so the old binding
   * must be replaced, not kept (mirrors FR-ID-04 "new key on re-registration").
   */
  reregister(
    accountId: string,
    platform: DevicePlatform,
    deviceModel: string,
    appVersion: string,
    now: Date,
    publicKeyHex: string,
  ): Device {
    return new Device(this.deviceId, accountId, platform, deviceModel, appVersion, this.registeredAt, now, true, publicKeyHex);
  }

  withLastSeen(now: Date): Device {
    return new Device(
      this.deviceId,
      this.accountId,
      this.platform,
      this.deviceModel,
      this.appVersion,
      this.registeredAt,
      now,
      this.active,
      this.publicKeyHex,
    );
  }

  disable(): Device {
    return new Device(
      this.deviceId,
      this.accountId,
      this.platform,
      this.deviceModel,
      this.appVersion,
      this.registeredAt,
      this.lastSeenAt,
      false,
      this.publicKeyHex,
    );
  }

  isInactive(now: Date, inactivityThresholdMs: number): boolean {
    return now.getTime() - this.lastSeenAt.getTime() > inactivityThresholdMs;
  }
}
