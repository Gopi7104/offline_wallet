import { Pool } from 'pg';
import { Device, DevicePlatform } from '../domain/device';
import { DeviceRepository } from '../domain/device_repository';

interface DeviceRow {
  device_id: string;
  account_id: string;
  platform: DevicePlatform;
  device_model: string;
  app_version: string;
  registered_at: Date;
  last_seen_at: Date;
  active: boolean;
  public_key: string | null;
}

function toDomain(row: DeviceRow): Device {
  return new Device(
    row.device_id,
    row.account_id,
    row.platform,
    row.device_model,
    row.app_version,
    row.registered_at,
    row.last_seen_at,
    row.active,
    row.public_key,
  );
}

/**
 * PgDeviceRepository — PostgreSQL adapter (migration 006 `device_registrations`).
 * Table name deliberately avoids `devices` — ARCHITECTURE.md §5.2 already
 * reserves that name for the future cryptographic device-binding feature
 * (public_key/attestation/op_counter_seen), which this is not.
 */
export class PgDeviceRepository implements DeviceRepository {
  constructor(private readonly pool: Pool) {}

  async findById(deviceId: string): Promise<Device | null> {
    const { rows } = await this.pool.query<DeviceRow>(
      'SELECT * FROM device_registrations WHERE device_id = $1',
      [deviceId],
    );
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async findByAccountId(accountId: string): Promise<Device[]> {
    const { rows } = await this.pool.query<DeviceRow>(
      'SELECT * FROM device_registrations WHERE account_id = $1 ORDER BY registered_at ASC',
      [accountId],
    );
    return rows.map(toDomain);
  }

  async save(device: Device): Promise<void> {
    await this.pool.query(
      `INSERT INTO device_registrations
         (device_id, account_id, platform, device_model, app_version, registered_at, last_seen_at, active, public_key)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (device_id) DO UPDATE SET
         account_id = EXCLUDED.account_id,
         platform = EXCLUDED.platform,
         device_model = EXCLUDED.device_model,
         app_version = EXCLUDED.app_version,
         last_seen_at = EXCLUDED.last_seen_at,
         active = EXCLUDED.active,
         public_key = EXCLUDED.public_key`,
      [
        device.deviceId,
        device.accountId,
        device.platform,
        device.deviceModel,
        device.appVersion,
        device.registeredAt,
        device.lastSeenAt,
        device.active,
        device.publicKeyHex,
      ],
    );
  }

  async findActiveNotSeenSince(cutoff: Date): Promise<Device[]> {
    const { rows } = await this.pool.query<DeviceRow>(
      'SELECT * FROM device_registrations WHERE active = true AND last_seen_at <= $1',
      [cutoff],
    );
    return rows.map(toDomain);
  }
}
