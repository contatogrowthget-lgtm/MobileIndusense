import 'package:flutter_test/flutter_test.dart';
import 'package:indusense/core/config/server_config.dart';
import 'package:indusense/models/camera_model.dart';

void main() {
  test('normaliza o endereço do servidor', () {
    expect(ServerConfig.normalize('192.168.1.20'), 'http://192.168.1.20:3333/v1');
    expect(ServerConfig.normalize('192.168.1.20:4000'), 'http://192.168.1.20:4000/v1');
    expect(ServerConfig.normalize('http://10.0.2.2:3333/v1/'), 'http://10.0.2.2:3333/v1');
  });

  test('junta os EPIs faltando em português', () {
    expect(juntarEpis(['capacete']), 'capacete');
    expect(juntarEpis(['capacete', 'luvas']), 'capacete e luvas');
    expect(juntarEpis(['capacete', 'oculos', 'luvas']), 'capacete, óculos e luvas');
  });
}
