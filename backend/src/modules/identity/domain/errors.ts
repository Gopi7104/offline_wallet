import { DomainError } from '../../../shared/errors';

/** The `platform` field on a device registration isn't one of the supported values. */
export class InvalidDevicePlatform extends DomainError {
  readonly code = 'INVALID_PLATFORM';
  constructor(platform: string) {
    super(`Unsupported device platform '${platform}' (expected android, ios, or web)`);
  }
}

/** The `publicKey` field on a device registration isn't a well-formed Ed25519 public key. */
export class InvalidDevicePublicKey extends DomainError {
  readonly code = 'INVALID_PUBLIC_KEY';
  constructor() {
    super('publicKey must be a 32-byte Ed25519 public key, hex-encoded (64 hex chars)');
  }
}

/** A device lookup (last-seen, etc.) found no device, or the device belongs to a different account. */
export class DeviceNotFound extends DomainError {
  readonly code = 'DEVICE_NOT_FOUND';
  constructor(deviceId: string) {
    super(`No device '${deviceId}' registered for this account`);
  }
}

/** A registration attempt reused a deviceId already owned by a different account. */
export class DeviceOwnershipConflict extends DomainError {
  readonly code = 'DEVICE_OWNERSHIP_CONFLICT';
  constructor(deviceId: string) {
    super(`Device '${deviceId}' is already registered to a different account`);
  }
}
