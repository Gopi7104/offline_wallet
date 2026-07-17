import { Request, Response } from 'express';
import { DeviceService } from '../application/device_service';
import { Device } from '../domain/device';
import { InvalidDevicePlatform, InvalidDevicePublicKey, DeviceNotFound, DeviceOwnershipConflict } from '../domain/errors';
import { sendError, sendInternalError } from '../../../shared/http_errors';
import { logger } from '../../../platform/logger';

// Sanity caps on free-text input — resource-exhaustion hygiene, not business rules.
const MAX_DEVICE_ID_LENGTH = 128;
const MAX_DEVICE_MODEL_LENGTH = 200;
const MAX_APP_VERSION_LENGTH = 50;

/** HTTP controller (interface adapter) for Device Registration (production hardening §1). */
export class DeviceController {
  constructor(private readonly service: DeviceService) {}

  /** POST /v1/devices/register */
  async register(req: Request, res: Response): Promise<void> {
    try {
      const accountId = req.accountId ?? 'test-account-1';
      const { deviceId, platform, deviceModel, appVersion, publicKey } = (req.body ?? {}) as Record<string, unknown>;

      if (typeof deviceId !== 'string' || deviceId.trim() === '' || deviceId.length > MAX_DEVICE_ID_LENGTH) {
        sendError(res, 400, 'INVALID_DEVICE_ID', `deviceId is required (max ${MAX_DEVICE_ID_LENGTH} chars)`);
        return;
      }
      if (typeof platform !== 'string' || platform.trim() === '') {
        sendError(res, 400, 'INVALID_PLATFORM', 'platform is required');
        return;
      }
      if (
        typeof deviceModel !== 'string' ||
        deviceModel.trim() === '' ||
        deviceModel.length > MAX_DEVICE_MODEL_LENGTH
      ) {
        sendError(res, 400, 'INVALID_DEVICE_MODEL', `deviceModel is required (max ${MAX_DEVICE_MODEL_LENGTH} chars)`);
        return;
      }
      if (
        typeof appVersion !== 'string' ||
        appVersion.trim() === '' ||
        appVersion.length > MAX_APP_VERSION_LENGTH
      ) {
        sendError(res, 400, 'INVALID_APP_VERSION', `appVersion is required (max ${MAX_APP_VERSION_LENGTH} chars)`);
        return;
      }
      if (typeof publicKey !== 'string' || publicKey.trim() === '') {
        sendError(res, 400, 'INVALID_PUBLIC_KEY', 'publicKey is required (hex-encoded Ed25519 public key)');
        return;
      }

      const device = await this.service.register(accountId, deviceId, platform, deviceModel, appVersion, publicKey);
      logger.info('device.registered', { accountId, deviceId, platform });
      res.status(201).json(this.toJson(device));
    } catch (error) {
      this.handleError(error, res);
    }
  }

  /** POST /v1/devices/:deviceId/last-seen */
  async touchLastSeen(req: Request, res: Response): Promise<void> {
    try {
      const accountId = req.accountId ?? 'test-account-1';
      const { deviceId } = req.params;
      if (!deviceId) {
        sendError(res, 400, 'INVALID_DEVICE_ID', 'deviceId is required');
        return;
      }
      const device = await this.service.updateLastSeen(accountId, deviceId);
      res.status(200).json(this.toJson(device));
    } catch (error) {
      this.handleError(error, res);
    }
  }

  /** GET /v1/devices — list the caller's own registered devices. */
  async list(req: Request, res: Response): Promise<void> {
    try {
      const accountId = req.accountId ?? 'test-account-1';
      const devices = await this.service.listByAccount(accountId);
      res.status(200).json({ devices: devices.map((d) => this.toJson(d)) });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private toJson(d: Device) {
    return {
      deviceId: d.deviceId,
      accountId: d.accountId,
      platform: d.platform,
      deviceModel: d.deviceModel,
      appVersion: d.appVersion,
      registeredAt: d.registeredAt.toISOString(),
      lastSeenAt: d.lastSeenAt.toISOString(),
      active: d.active,
    };
  }

  private handleError(error: unknown, res: Response): void {
    if (error instanceof InvalidDevicePlatform || error instanceof InvalidDevicePublicKey) {
      sendError(res, 400, error.code, error.message);
      return;
    }
    if (error instanceof DeviceNotFound) {
      sendError(res, 404, error.code, error.message);
      return;
    }
    if (error instanceof DeviceOwnershipConflict) {
      sendError(res, 409, error.code, error.message);
      return;
    }
    logger.error('device.controller_error', { message: (error as Error).message });
    sendInternalError(res);
  }
}
