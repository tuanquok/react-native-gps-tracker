# Hướng dẫn khai báo Info.plist cho iOS

File mẫu của dự án nằm tại:

```text
example/ios/GpsTrackerExample/Info.plist
```

Thư viện `react-native-gps-tracker` dùng `CoreLocation` để lấy vị trí, tiếp tục theo dõi vị trí khi app chạy nền, và dùng `CoreMotion` để tối ưu việc bật/tắt GPS khi thiết bị di chuyển hoặc đứng yên. Vì vậy app iOS cần khai báo đúng các quyền bên dưới trong `Info.plist`.

## Các key bắt buộc

### `NSLocationAlwaysAndWhenInUseUsageDescription`

Thông báo này hiển thị khi app xin quyền truy cập vị trí ở mức `Always`.

Thư viện gọi:

```swift
locationManager.requestAlwaysAuthorization()
```

Vì vậy key này là bắt buộc nếu app cần tracking vị trí khi đang chạy nền.

Ví dụ:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Ứng dụng cần truy cập vị trí kể cả khi chạy nền để ghi nhận hành trình GPS.</string>
```

Nên viết nội dung rõ ràng theo đúng tính năng thực tế của app. Không nên để chung chung như `Need background GPS tracking` khi đưa lên App Store.

### `NSLocationWhenInUseUsageDescription`

Thông báo này hiển thị khi app xin quyền truy cập vị trí khi người dùng đang mở app.

Mặc dù thư viện xin `Always`, iOS vẫn cần chuỗi giải thích cho quyền `When In Use` trong luồng cấp quyền vị trí.

Ví dụ:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Ứng dụng cần truy cập vị trí khi bạn đang sử dụng app để lấy tọa độ hiện tại.</string>
```

Không nên để chuỗi rỗng:

```xml
<string></string>
```

Chuỗi rỗng có thể làm trải nghiệm xin quyền kém rõ ràng và dễ bị từ chối khi review.

### `UIBackgroundModes`

Key này cho phép app tiếp tục nhận cập nhật vị trí khi chạy nền.

Thư viện cấu hình:

```swift
locationManager.allowsBackgroundLocationUpdates = true
locationManager.startMonitoringSignificantLocationChanges()
locationManager.startUpdatingLocation()
```

Vì vậy `UIBackgroundModes` cần có giá trị `location`.

Ví dụ:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

Nếu thiếu key này, app có thể lấy vị trí khi đang mở nhưng không hoạt động đúng khi vào background.

### `NSMotionUsageDescription`

Thư viện dùng `CoreMotion` để theo dõi trạng thái chuyển động của thiết bị, từ đó tối ưu tracking GPS.

Ví dụ:

```xml
<key>NSMotionUsageDescription</key>
<string>Ứng dụng sử dụng dữ liệu chuyển động để tối ưu việc theo dõi GPS khi bạn di chuyển.</string>
```

Nếu app không khai báo key này mà có truy cập Motion Activity, iOS có thể chặn quyền hoặc làm app lỗi khi request dữ liệu motion.

## Đoạn khai báo mẫu

Chèn các key sau vào bên trong thẻ `<dict>` của `Info.plist`:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Ứng dụng cần truy cập vị trí kể cả khi chạy nền để ghi nhận hành trình GPS.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Ứng dụng cần truy cập vị trí khi bạn đang sử dụng app để lấy tọa độ hiện tại.</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

<key>NSMotionUsageDescription</key>
<string>Ứng dụng sử dụng dữ liệu chuyển động để tối ưu việc theo dõi GPS khi bạn di chuyển.</string>
```

## Cấu hình từ Xcode

Có thể khai báo trực tiếp bằng Xcode:

1. Mở `example/ios/GpsTrackerExample.xcworkspace`.
2. Chọn target `GpsTrackerExample`.
3. Vào tab `Info` để thêm các Privacy key:
   - `Privacy - Location Always and When In Use Usage Description`
   - `Privacy - Location When In Use Usage Description`
   - `Privacy - Motion Usage Description`
4. Vào tab `Signing & Capabilities`.
5. Thêm capability `Background Modes`.
6. Bật `Location updates`.

## Khai báo trong AppDelegate

Ngoài `Info.plist`, app iOS nên gọi `restoreTrackingIfNeeded()` trong `AppDelegate` để thư viện khôi phục tracking khi app được mở lại hoặc được hệ thống đánh thức sau khi đã bật tracking trước đó.

Trong `AppDelegate.swift`, import module:

```swift
import GpsTracker
```

Sau đó gọi `GPSManager.shared.restoreTrackingIfNeeded()` trong `application(_:didFinishLaunchingWithOptions:)`.

Ví dụ:

```swift
func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
  // Khởi tạo React Native...

  GPSManager.shared.restoreTrackingIfNeeded()

  return true
}
```

Dòng này không thay thế việc gọi `startTracking()` từ React Native. Luồng sử dụng đúng là:

```ts
requestPermission();
startTracking();
```

`requestPermission()` và `startTracking()` dùng để xin quyền và bật tracking lần đầu. `restoreTrackingIfNeeded()` trong `AppDelegate` chỉ dùng để khôi phục tracking nếu trước đó người dùng đã bật tracking và app bị restart hoặc launch lại.

Các hàm như `applicationDidEnterBackground` hoặc `applicationWillTerminate` trong app mẫu hiện chỉ dùng để in log debug, không bắt buộc phải copy sang dự án thật.

## Lưu ý khi dùng cho app thực tế

- Nội dung usage description nên nói rõ app lấy vị trí để làm gì, lấy khi nào, và lợi ích cho người dùng.
- Nếu cần tracking nền, người dùng phải cấp quyền `Always`; quyền `When In Use` không đủ cho background tracking ổn định.
- Sau khi sửa `Info.plist`, nên clean build app iOS nếu thấy prompt quyền chưa cập nhật.
- Khi test lại luồng xin quyền, có thể xóa app khỏi thiết bị/simulator để reset trạng thái quyền.
