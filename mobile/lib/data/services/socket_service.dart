import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/config/app_config.dart';

typedef EventCallback = void Function(dynamic data);

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  final Map<String, List<EventCallback>> _listeners = {};

  SocketService._();
  static SocketService get instance => _instance ??= SocketService._();

  void connect(String token) {
    _socket = IO.io(
      AppConfig.baseUrl.replaceAll('/api/v1', ''),
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => print('Socket connected'));
    _socket!.onDisconnect((_) => print('Socket disconnected'));
    _socket!.onConnectError((e) => print('Socket connect error: $e'));

    // Re-bind any cached listeners
    _listeners.forEach((event, cbs) {
      for (final cb in cbs) {
        _socket!.on(event, cb);
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void emit(String event, dynamic data) => _socket?.emit(event, data);

  void on(String event, EventCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  void off(String event, [EventCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      _socket?.off(event, callback);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  void updateRiderLocation(double lat, double lng) {
    emit('rider:location', {'lat': lat, 'lng': lng});
  }

  void setRiderAvailability(bool online) {
    emit('rider:availability', {'online': online});
  }

  void trackRider(String riderId) {
    emit('track:rider', {'rider_id': riderId});
  }

  bool get isConnected => _socket?.connected ?? false;
}
