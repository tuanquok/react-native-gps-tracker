import GpsTracker from './NativeGpsTracker';

/**
 * Gia tri JSON co the truyen tu JavaScript xuong native.
 */
export type JsonPrimitive = string | number | boolean | null;
export type JsonValue =
  | JsonPrimitive
  | { [key: string]: JsonValue }
  | JsonValue[];

/**
 * Cau hinh action gui location len API.
 *
 * Khi `batchSync` la `false` hoac khong khai bao, moi location moi se duoc
 * gui thanh mot request rieng.
 *
 * Khi `batchSync` la `true`, native se luu location vao queue va chi gui
 * request khi queue du so diem cau hinh.
 */
export type HttpActionConfig = {
  /**
   * Loai action. Dung `http` de gui location len API.
   */
  type: 'http';

  /**
   * Endpoint nhan location hoac batch location.
   */
  url: string;

  /**
   * HTTP method dung de gui request. Mac dinh native dung `POST`.
   */
  method?: 'POST' | 'PUT' | 'PATCH';

  /**
   * HTTP headers gui kem request.
   *
   * Neu khong khai bao `Content-Type`, native se tu set
   * `Content-Type: application/json`.
   */
  headers?: Record<string, string>;

  /**
   * Template JSON cho tung location.
   *
   * Co the dung cac bien:
   * - `$latitude`
   * - `$longitude`
   * - `$accuracy`
   * - `$altitude`
   * - `$speed`
   * - `$course`
   * - `$timestamp`
   *
   * Khi khong khai bao, native se gui toan bo payload location mac dinh.
   */
  body?: JsonValue;

  /**
   * Template JSON cho request batch.
   *
   * Dung `$locations` de chen mang cac `body` da gom vao request.
   * Neu khong khai bao, body request batch se la mang locations truc tiep.
   *
   * Vi du:
   * `{ locations: '$locations' }`
   */
  batchBody?: JsonValue;

  /**
   * Timeout cho HTTP request, tinh bang milliseconds.
   *
   * Luu y: iOS hien doc gia tri nay theo `TimeInterval`, nen nen truyen
   * seconds neu can timeout chinh xac o iOS. Phan nay co the duoc chuan hoa
   * sau de dung dung milliseconds tren ca hai nen tang.
   */
  timeoutMs?: number;

  /**
   * Co tu dong flush queue khi du dieu kien hay khong.
   *
   * Mac dinh la `true`. Neu set `false`, location chi duoc luu vao queue cho
   * den khi goi `sync()`.
   */
  autoSync?: boolean;

  /**
   * So location toi thieu de tu dong sync khi khong khai bao `maxBatchSize`.
   *
   * Neu co `maxBatchSize`, iOS uu tien `maxBatchSize` lam nguong gui request.
   */
  autoSyncThreshold?: number;

  /**
   * Bat che do gom location thanh batch truoc khi gui.
   *
   * Moi location se duoc render theo `body` roi luu vao native queue.
   * Khi du nguong, native gui mot request batch.
   */
  batchSync?: boolean;

  /**
   * So location can gom cho moi request batch.
   *
   * Vi du `maxBatchSize: 5` nghia la iOS gom du 5 location moi gui 1 request.
   * Sau response thanh cong `2xx`, native xoa dung batch da gui khoi queue.
   */
  maxBatchSize?: number;
};

/**
 * Cau hinh action ghi location ra file native.
 */
export type FileActionConfig = {
  /**
   * Loai action. Dung `file` de ghi location ra file.
   */
  type: 'file';

  /**
   * Ten file luu location. Neu khong khai bao, native dung ten mac dinh.
   */
  fileName?: string;
};

/**
 * Cau hinh tracking rieng cho Android.
 */
export type AndroidTrackerConfig = {
  /**
   * Khoang thoi gian toi thieu giua cac lan request location, tinh bang ms.
   *
   * Gia tri nay duoc truyen vao `LocationManager.requestLocationUpdates`
   * lam tham so `minTime`.
   */
  intervalMs?: number;

  /**
   * Khoang cach toi thieu tinh bang met truoc khi Android callback location.
   *
   * Gia tri nay duoc truyen vao `LocationManager.requestLocationUpdates`
   * lam tham so `minDistance`.
   */
  distanceFilterMeters?: number;

  /**
   * Danh sach provider Android su dung de lay location.
   *
   * - `gps`: chinh xac hon, ton pin hon.
   * - `network`: duoc tinh tu Wi-Fi/cell tower, tiet kiem hon nhung kem chinh xac hon.
   */
  providers?: Array<'gps' | 'network'>;

  /**
   * Co ghi location gan nhat cua provider ngay khi start service hay khong.
   */
  writeLastKnownLocationOnStart?: boolean;
};

/**
 * Cau hinh tracking rieng cho iOS.
 */
export type IosTrackerConfig = {
  /**
   * Khoang cach toi thieu tinh bang met truoc khi iOS callback location.
   *
   * Gia tri nay duoc gan vao `CLLocationManager.distanceFilter`.
   */
  distanceFilterMeters?: number;

  /**
   * Ban kinh vung dung yen, tinh bang met.
   *
   * Khi thiet bi dung yen, native tao `CLCircularRegion` quanh location cuoi.
   * Khi iOS bao da thoat khoi vung nay, native chuyen sang che do moving va
   * bat lai GPS tracking.
   */
  stationaryRadiusMeters?: number;
};

/**
 * Cau hinh tong cho thu vien GPS tracker.
 */
export type GpsTrackerConfig = {
  /**
   * Danh sach action se chay moi khi native nhan duoc location moi.
   */
  actions?: Array<HttpActionConfig | FileActionConfig>;

  /**
   * Cau hinh rieng cho Android.
   */
  android?: AndroidTrackerConfig;

  /**
   * Cau hinh rieng cho iOS.
   */
  ios?: IosTrackerConfig;
};

/**
 * Luu cau hinh tracking/action xuong native.
 */
export function configure(config: GpsTrackerConfig) {
  return GpsTracker.configure(config);
}

/**
 * Xin quyen location tu nguoi dung.
 */
export function requestPermission() {
  return GpsTracker.requestPermission();
}

/**
 * Bat dau tracking location.
 */
export function startTracking() {
  return GpsTracker.startTracking();
}

/**
 * Dung tracking location.
 */
export function stopTracking() {
  return GpsTracker.stopTracking();
}

/**
 * Yeu cau native lay location hien tai mot lan.
 */
export function getCurrentLocation() {
  return GpsTracker.getCurrentLocation();
}

/**
 * Flush queue batch HTTP thu cong.
 *
 * Huu ich khi `autoSync` la `false`. Native chi gui khi queue du
 * nguong batch hien tai.
 */
export function sync() {
  return GpsTracker.sync();
}
