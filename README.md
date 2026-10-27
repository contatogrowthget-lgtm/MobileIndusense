# InduSense — Monitoramento Ambiental Industrial (Growth Get)

## Novidades: visual novo, câmera, EPI e API real

- **Visual novo**: início com saudação, painel "ao vivo" com o estado geral da fábrica, indicadores (sensores online,
  alertas, pessoas nas câmeras, conformidade de EPI), câmera ao vivo direto no início, salas com as leituras atuais
  de cada sensor e alertas recentes. Animações de entrada, barra de navegação flutuante e contador de alertas pendentes.
- **Aba Câmeras**: todas as câmeras com vídeo ao vivo, pessoas, conformidade e ocorrência atual.
- **Sensores** com a posição do valor dentro dos limites (barra verde → vermelho).

- **Câmera ao vivo** na tela da sala (ex.: Linha de Produção A), com o mesmo vídeo do sistema de câmera.
  Toque no vídeo ou no botão de expandir para abrir a **tela cheia**: pessoas agora, EPIs de cada uma,
  contadores e ocorrências com foto — os mesmos números de `http://localhost:8000`.
- **Conformidade de EPI** na sala: percentual, pessoas na cena e percentual por item (capacete, óculos, colete, luvas).
- **Alertas** com duas abas: *Sensores* e *EPI* (fotos das ocorrências e botão "Marcar como resolvida").
- **Dashboard** com o card de EPI (câmeras online, conformidade média, ocorrências abertas e de hoje).
- **Servidor configurável dentro do app** (Perfil > Servidor, ou "Servidor" na tela de login): troque entre
  emulador, simulador e celular sem recompilar. Tem botão de testar a conexão.
- Sessão não cai quando o servidor está fora do ar (só sai se o token expirar).
- Mensagens de erro claras ("Sem conexão com o servidor em …").
- Android: permissões de internet, NFC e `http://` liberadas. iOS: `http://` na rede local e textos de NFC/rede local.

### Endereço do servidor

| Onde o app roda | Endereço |
|---|---|
| macOS (desktop) ou simulador do iPhone | `http://localhost:3333/v1` |
| Emulador Android | `http://10.0.2.2:3333/v1` |
| Celular de verdade (mesmo Wi-Fi) | `http://IP-DO-MAC:3333/v1` (veja o IP em Ajustes > Wi-Fi > Detalhes) |

O vídeo da câmera vem do endereço que o sistema de câmera informa à API. Se ele disser `localhost`,
o app troca sozinho pelo IP do servidor configurado.

### Rodar

```
flutter pub get
flutter run            # escolha macOS, simulador ou celular
```

Login de teste: `admin@indusense.com` / `123456`.

---


App Flutter/FlutterFlow para monitoramento em tempo real de sensores
IoT/ESP32 (temperatura, umidade, qualidade do ar e gases), agora
**organizado por sala/setor** e com **leitura de tag NFC na porta**
para abrir os sensores daquele ambiente automaticamente. Backend:
Nest.js + PostgreSQL, API REST/JSON.

## Changelog desta revisão

- ✅ Corrigido o overflow "RIGHT OVERFLOWED BY N PIXELS" nos cards do
  Dashboard (o valor + status pill agora empilham em vez de dividir
  uma `Row` com `Spacer`, e usam `FittedBox` para nunca estourar).
- ✅ Corrigido o wrap quebrado dos rótulos do eixo Y nos gráficos
  (Histórico e Detalhe do Sensor) — labels sem casas decimais e
  `reservedSize` maior.
- ✅ Grid de sensores trocado de `childAspectRatio` fixo para
  `SliverGridDelegateWithMaxCrossAxisExtent`, que adapta o número de
  colunas ao tamanho real da tela (celular pequeno, celular grande,
  tablet) em vez de sempre forçar 2 colunas.
- ✅ **Novo:** Dashboard agora agrupa os sensores por **sala/setor**
  (`SalaModel`), mostrando o status geral de cada sala e navegando
  para a lista de sensores daquela sala ao tocar.
- ✅ **Novo:** tela de **leitura de tag NFC** (`/nfc-scan`) — ao
  aproximar o celular da tag fixada na porta da sala, o app resolve
  automaticamente qual sala é e abre a lista de sensores dela.

## 1. Estrutura de pastas (atualizada)

```
lib/
├── main.dart
├── core/
│   ├── theme/app_theme.dart
│   └── constants/api_constants.dart
├── models/
│   ├── user_model.dart
│   ├── sensor_model.dart          # + campo salaId
│   ├── sala_model.dart            # NOVO: SalaModel, SalaComSensores
│   ├── reading_model.dart
│   └── alert_model.dart
├── services/
│   ├── api_client.dart
│   ├── auth_service.dart
│   ├── auth_provider.dart
│   ├── sensor_service.dart
│   ├── sala_service.dart          # NOVO: agrupamento por sala + NFC→sala
│   ├── nfc_service.dart           # NOVO: leitura de tags via nfc_manager
│   ├── alert_service.dart
│   └── mock_data_service.dart     # + salas mockadas
├── widgets/
│   ├── sensor_card.dart           # corrigido (sem overflow)
│   ├── sala_card.dart             # NOVO: card de sala no dashboard
│   ├── status_indicator.dart
│   └── state_widgets.dart
├── screens/
│   ├── splash/splash_screen.dart
│   ├── auth/login_screen.dart
│   ├── auth/cadastro_screen.dart
│   ├── dashboard/dashboard_screen.dart   # reescrito: lista de salas
│   ├── sala_detail/sala_detail_screen.dart # NOVO: sensores de 1 sala
│   ├── nfc/nfc_scan_screen.dart          # NOVO: tela de leitura NFC
│   ├── historico/historico_screen.dart   # gráfico corrigido
│   ├── sensor_detail/sensor_detail_screen.dart # gráfico corrigido
│   ├── alertas/alertas_screen.dart
│   ├── configuracoes/configuracoes_screen.dart
│   └── home_shell.dart
└── routes/app_routes.dart          # + /sala-detalhe, /nfc-scan
```

## 2. Navegação (atualizada)

```
/            → Splash
/login       → Login
/cadastro    → Cadastro
/dashboard   → HomeShell(0) → Dashboard (lista de SALAS)
/historico   → HomeShell(1) → Histórico
/alertas     → HomeShell(2) → Alertas
/configuracoes → HomeShell(3) → Perfil
/sala-detalhe   → SalaDetailScreen  (arg: salaId)   → sensores da sala
/sensor-detalhe → SensorDetailScreen (arg: sensorId) → gráfico do sensor
/nfc-scan       → NfcScanScreen → lê a tag e navega para /sala-detalhe
```

Fluxo do NFC: `NfcScanScreen` inicia uma sessão de leitura
(`NfcService`); ao detectar uma tag, extrai um identificador de texto
(NDEF) ou o serial de hardware como fallback; esse identificador é
resolvido para uma sala via `SalaService.getSalaPorTagNfc`; em caso de
sucesso, navega (`pushReplacementNamed`) direto para `/sala-detalhe`
com os sensores daquele ambiente.

## 3. Models (novo: Sala)

| Model | Campos principais |
|---|---|
| `SalaModel` | id, nome, setor, **nfcTagId** |
| `SalaComSensores` | sala (`SalaModel`), sensores (`List<SensorModel>`), `statusGeral` (getter: pior status entre os sensores), `totalAlertas` (getter) |
| `SensorModel` | ... campos já existentes + **salaId** (referencia a sala) |

## 4. Endpoints novos (Nest.js) + JSON

### Salas

**GET `/salas`**
```json
[
  { "id": "sala1", "nome": "Linha de Produção A", "setor": "Galpão 1", "nfcTagId": "NFC-GALPAO1-LINHA-A" }
]
```

**GET `/salas/:id`** → objeto único no formato acima.

**GET `/salas/:id/sensors`** → lista de `SensorModel` (mesmo formato do endpoint `/sensors`), filtrados por sala.

**GET `/salas/nfc/:tagId`** → resolve a sala a partir do identificador
gravado na tag NFC. Retorna 404 se nenhuma sala estiver associada.
```json
// GET /salas/nfc/NFC-GALPAO1-LINHA-A
{ "id": "sala1", "nome": "Linha de Produção A", "setor": "Galpão 1", "nfcTagId": "NFC-GALPAO1-LINHA-A" }
```

> `SensorModel` agora inclui `"salaId": "sala1"` no JSON de resposta de
> `/sensors` e `/sensors/:id`, para permitir agrupamento no cliente
> mesmo sem chamar `/salas/:id/sensors`.

## 5. Configuração nativa para NFC

O pacote usado é `nfc_manager`. Como este pacote depende de código
nativo, é necessário configurar Android e iOS **depois** de rodar
`flutter create .` no projeto (caso ainda não existam as pastas
`android/` e `ios/`):

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />
```
`required="false"` permite instalar em aparelhos sem NFC — a tela
`NfcScanScreen` já trata esse caso (`NfcService.isDisponivel()`) e
mostra uma mensagem clara em vez de travar.

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NFCReaderUsageDescription</key>
<string>Usamos NFC para identificar a sala ao aproximar da tag na porta.</string>
```
E em **Signing & Capabilities** (Xcode), habilitar "Near Field
Communication Tag Reading". Isso gera automaticamente a entitlement
`com.apple.developer.nfc.readersession.formats`.

### Tags NFC recomendadas
Tags NTAG213/215/216 (NFC Forum Type 2), graváveis com um registro
NDEF de texto simples contendo o identificador da sala (ex.:
`NFC-GALPAO1-LINHA-A`). Podem ser gravadas com qualquer app leitor/
gravador de NFC antes de fixar na porta.

## 6. Correções de responsividade (detalhe técnico)

- **`SensorCard`**: o valor (`24.6 °C`) e o status (`Normal`) estavam
  na mesma `Row` com `Spacer()`; em grids de 2+ colunas ou telas
  estreitas, a soma das larguras passava do disponível → overflow.
  Agora ficam empilhados (`Column`), e o valor usa `FittedBox` para
  encolher se necessário (ex.: `168.0 IQA` em um card pequeno).
- **Gráficos (`fl_chart`)**: os rótulos do eixo Y quebravam linha no
  meio do número (`26.` / `6`) porque o texto com casas decimais não
  cabia na largura reservada. Agora os rótulos são inteiros
  (`toStringAsFixed(0)`) e a largura reservada aumentou de 36 para 40.
- **Grid do Dashboard/Sala**: trocado `childAspectRatio` fixo por
  `SliverGridDelegateWithMaxCrossAxisExtent` (190 lógico px por
  célula) — o Flutter calcula sozinho quantas colunas cabem, então o
  mesmo código funciona bem em celular pequeno, celular grande e
  tablet, sem overflow vertical nem horizontal.
- **Chips de resumo do Dashboard**: agora usam `LayoutBuilder` para
  decidir entre 4 colunas (telas normais) ou 2x2 (telas muito
  estreitas), em vez de forçar 4 `Expanded` fixos.

## 7. Configurações necessárias no FlutterFlow

Além do que já estava documentado (Custom Data Types, API Calls, App
State, tema, `fl_chart`/`intl`):

1. **Custom Data Type `SalaModel`**: campos `id`, `nome`, `setor`,
   `nfcTagId` (todos String).
2. **API Calls novas**: `GET /salas`, `GET /salas/:id/sensors`,
   `GET /salas/nfc/:tagId` — habilitar "Available in Custom Actions"
   para poder chamá-las a partir da action de leitura NFC.
3. **NFC não tem widget nativo no FlutterFlow.** É necessário criar
   uma **Custom Action** em Dart que:
   - importe `nfc_manager`;
   - inicie a sessão (`NfcManager.instance.startSession`);
   - no callback `onDiscovered`, extraia o identificador da tag
     (mesma lógica de `lib/services/nfc_service.dart`, que pode ser
     colada quase inteira dentro da Custom Action);
   - retorne o `tagId` (String) para a página, que então chama a API
     `GET /salas/nfc/:tagId` e navega para a página de detalhe da sala
     passando o `salaId` retornado.
4. **Página "Escanear Sala"**: um botão/FAB no Dashboard chamando essa
   Custom Action; enquanto aguarda, mostrar um ícone de NFC animado
   (Lottie ou ícone estático) — replicando `NfcScanScreen`.
5. **Dashboard**: trocar o Repeating Element de "sensores" por um
   Repeating Element de "salas" (`GET /salas` combinado com a contagem
   de sensores por sala), navegando para uma página "Detalhe da Sala"
   que lista os sensores filtrados por `salaId`.
6. **Permissões nativas**: em Project Settings → Permissions,
   habilitar NFC (Android) e, no build exportado para Xcode, adicionar
   a capability "Near Field Communication Tag Reading" antes de
   publicar na App Store.

## 8. Rodando localmente (Flutter puro)

```bash
flutter pub get
flutter run
```

Funciona 100% com dados mockados (`ApiConstants.useMock = true`),
incluindo o botão **"Simular leitura (modo teste)"** na tela de NFC,
útil para testar o fluxo em emuladores ou aparelhos sem chip NFC.
Para conectar à API real, altere `useMock` para `false` e ajuste
`baseUrl` em `lib/core/constants/api_constants.dart`.
# MobileIndusense
