import request from 'supertest';
import { createServer } from '../src/platform/httpServer';
import { InMemoryDeviceRepository } from '../src/modules/identity/infra/in_memory_device_repository';
import { DeviceService } from '../src/modules/identity/application/device_service';
import {
  InvalidDevicePlatform,
  InvalidDevicePublicKey,
  DeviceNotFound,
  DeviceOwnershipConflict,
} from '../src/modules/identity/domain/errors';

const FIXED_NOW = new Date('2026-07-16T10:00:00.000Z');

/** Ed25519 public keys are 32 bytes, hex-encoded (64 chars) — arbitrary fixed test values. */
const PUB_KEY_1 = '11'.repeat(32);
const PUB_KEY_2 = '22'.repeat(32);

describe('DeviceService (application, production hardening §1 + Task 9 owner-signed transfers)', () => {
  let repo: InMemoryDeviceRepository;
  let service: DeviceService;

  beforeEach(() => {
    repo = new InMemoryDeviceRepository();
    service = new DeviceService(repo, () => FIXED_NOW);
  });

  it('registers a new device with its public key', async () => {
    const device = await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    expect(device.deviceId).toBe('device-1');
    expect(device.accountId).toBe('acct-1');
    expect(device.platform).toBe('android');
    expect(device.deviceModel).toBe('Pixel 8');
    expect(device.appVersion).toBe('1.0.0');
    expect(device.registeredAt).toEqual(FIXED_NOW);
    expect(device.lastSeenAt).toEqual(FIXED_NOW);
    expect(device.active).toBe(true);
    expect(device.publicKeyHex).toBe(PUB_KEY_1);
  });

  it('rejects an unsupported platform', async () => {
    await expect(
      service.register('acct-1', 'device-1', 'windows', 'PC', '1.0.0', PUB_KEY_1),
    ).rejects.toBeInstanceOf(InvalidDevicePlatform);
  });

  it('rejects a malformed public key (wrong length)', async () => {
    await expect(
      service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', 'ab'.repeat(16)),
    ).rejects.toBeInstanceOf(InvalidDevicePublicKey);
  });

  it('rejects a malformed public key (non-hex characters)', async () => {
    await expect(
      service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', 'zz'.repeat(32)),
    ).rejects.toBeInstanceOf(InvalidDevicePublicKey);
  });

  it('rejects re-registering a deviceId already owned by a different account (no silent hijack)', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    await expect(
      service.register('acct-2', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_2),
    ).rejects.toBeInstanceOf(DeviceOwnershipConflict);
    // The original owner's record is untouched.
    const devices = await service.listByAccount('acct-1');
    expect(devices).toHaveLength(1);
    expect(devices[0]?.accountId).toBe('acct-1');
  });

  it('re-registration is idempotent on deviceId: refreshes details, keeps original registeredAt', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    const later = new Date(FIXED_NOW.getTime() + 86_400_000);
    const service2 = new DeviceService(repo, () => later);

    const reregistered = await service2.register('acct-1', 'device-1', 'android', 'Pixel 9', '2.0.0', PUB_KEY_1);
    expect(reregistered.deviceModel).toBe('Pixel 9');
    expect(reregistered.appVersion).toBe('2.0.0');
    expect(reregistered.registeredAt).toEqual(FIXED_NOW); // unchanged
    expect(reregistered.lastSeenAt).toEqual(later);
  });

  it('re-registration rotates the public key (a fresh install generates a fresh device key)', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    const reregistered = await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.1', PUB_KEY_2);
    expect(reregistered.publicKeyHex).toBe(PUB_KEY_2);
  });

  it('re-registering a disabled device reactivates it', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    const disabled = await service.disableInactiveDevices(0); // threshold 0ms: everything not-seen-since "now" qualifies
    expect(disabled.map((d) => d.deviceId)).toEqual(['device-1']);

    const reregistered = await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.1', PUB_KEY_1);
    expect(reregistered.active).toBe(true);
  });

  it('updateLastSeen refreshes the timestamp for the owning account', async () => {
    await service.register('acct-1', 'device-1', 'ios', 'iPhone 15', '1.0.0', PUB_KEY_1);
    const later = new Date(FIXED_NOW.getTime() + 3600_000);
    const service2 = new DeviceService(repo, () => later);
    const updated = await service2.updateLastSeen('acct-1', 'device-1');
    expect(updated.lastSeenAt).toEqual(later);
  });

  it('updateLastSeen throws DeviceNotFound for an unknown device', async () => {
    await expect(service.updateLastSeen('acct-1', 'does-not-exist')).rejects.toBeInstanceOf(DeviceNotFound);
  });

  it('updateLastSeen throws DeviceNotFound when the device belongs to a different account (no cross-account access)', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    await expect(service.updateLastSeen('acct-2', 'device-1')).rejects.toBeInstanceOf(DeviceNotFound);
  });

  it('listByAccount returns only that account devices', async () => {
    await service.register('acct-1', 'device-1', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    await service.register('acct-1', 'device-2', 'ios', 'iPhone 15', '1.0.0', PUB_KEY_2);
    await service.register('acct-2', 'device-3', 'android', 'Pixel 7', '1.0.0', PUB_KEY_1);

    const devices = await service.listByAccount('acct-1');
    expect(devices.map((d) => d.deviceId).sort()).toEqual(['device-1', 'device-2']);
  });

  it('disableInactiveDevices disables only devices not seen since the cutoff, and leaves recently-seen devices active', async () => {
    await service.register('acct-1', 'stale-device', 'android', 'Pixel 8', '1.0.0', PUB_KEY_1);
    const recent = new Date(FIXED_NOW.getTime() + 1000);
    const recentService = new DeviceService(repo, () => recent);
    await recentService.register('acct-1', 'fresh-device', 'android', 'Pixel 8', '1.0.0', PUB_KEY_2);

    const cutoffService = new DeviceService(repo, () => new Date(recent.getTime() + 500));
    const disabled = await cutoffService.disableInactiveDevices(600); // only "stale-device" is older than 600ms
    expect(disabled.map((d) => d.deviceId)).toEqual(['stale-device']);

    const remaining = await repo.findByAccountId('acct-1');
    const fresh = remaining.find((d) => d.deviceId === 'fresh-device')!;
    const stale = remaining.find((d) => d.deviceId === 'stale-device')!;
    expect(fresh.active).toBe(true);
    expect(stale.active).toBe(false);
  });

  it('"unknown device" — a lookup for a deviceId that was never registered finds nothing (no public key to trust)', async () => {
    expect(await repo.findById('never-registered')).toBeNull();
    await expect(service.updateLastSeen('acct-1', 'never-registered')).rejects.toBeInstanceOf(DeviceNotFound);
  });
});

describe('Device Registration HTTP (production hardening §1 + Task 9 owner-signed transfers)', () => {
  const app = createServer();

  it('POST /v1/devices/register: 201 with the registered device', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-1')
      .send({
        deviceId: 'http-device-1',
        platform: 'android',
        deviceModel: 'Pixel 8',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_1,
      });

    expect(res.status).toBe(201);
    expect(res.body.deviceId).toBe('http-device-1');
    expect(res.body.accountId).toBe('http-device-acct-1');
    expect(res.body.active).toBe(true);
  });

  it('POST /v1/devices/register: 400 INVALID_PLATFORM for an unsupported platform', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-2')
      .send({
        deviceId: 'http-device-2',
        platform: 'windows',
        deviceModel: 'PC',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_1,
      });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('INVALID_PLATFORM');
  });

  it('POST /v1/devices/register: 400 for a missing deviceId', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-3')
      .send({ platform: 'android', deviceModel: 'Pixel 8', appVersion: '1.0.0', publicKey: PUB_KEY_1 });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('INVALID_DEVICE_ID');
  });

  it('POST /v1/devices/register: 400 INVALID_PUBLIC_KEY for a missing public key', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-3b')
      .send({ deviceId: 'http-device-3b', platform: 'android', deviceModel: 'Pixel 8', appVersion: '1.0.0' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('INVALID_PUBLIC_KEY');
  });

  it('POST /v1/devices/register: 400 INVALID_PUBLIC_KEY for a malformed (non-hex) public key', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-3c')
      .send({
        deviceId: 'http-device-3c',
        platform: 'android',
        deviceModel: 'Pixel 8',
        appVersion: '1.0.0',
        publicKey: 'not-hex',
      });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('INVALID_PUBLIC_KEY');
  });

  it('POST /v1/devices/:deviceId/last-seen: 200 and refreshes lastSeenAt', async () => {
    await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-4')
      .send({
        deviceId: 'http-device-4',
        platform: 'ios',
        deviceModel: 'iPhone 15',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_1,
      });

    const res = await request(app)
      .post('/v1/devices/http-device-4/last-seen')
      .set('x-account-id', 'http-device-acct-4');
    expect(res.status).toBe(200);
    expect(res.body.deviceId).toBe('http-device-4');
  });

  it('POST /v1/devices/:deviceId/last-seen: 404 for a device owned by a different account', async () => {
    await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-5')
      .send({
        deviceId: 'http-device-5',
        platform: 'android',
        deviceModel: 'Pixel 8',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_1,
      });

    const res = await request(app)
      .post('/v1/devices/http-device-5/last-seen')
      .set('x-account-id', 'someone-else');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('DEVICE_NOT_FOUND');
  });

  it('GET /v1/devices: lists only the caller own devices', async () => {
    await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-6')
      .send({
        deviceId: 'http-device-6a',
        platform: 'android',
        deviceModel: 'Pixel 8',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_1,
      });
    await request(app)
      .post('/v1/devices/register')
      .set('x-account-id', 'http-device-acct-6')
      .send({
        deviceId: 'http-device-6b',
        platform: 'ios',
        deviceModel: 'iPhone 15',
        appVersion: '1.0.0',
        publicKey: PUB_KEY_2,
      });

    const res = await request(app).get('/v1/devices').set('x-account-id', 'http-device-acct-6');
    expect(res.status).toBe(200);
    expect(res.body.devices.map((d: { deviceId: string }) => d.deviceId).sort()).toEqual([
      'http-device-6a',
      'http-device-6b',
    ]);
  });
});
