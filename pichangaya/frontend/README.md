# PichangaYa — Frontend (Flutter)

App móvil Android/iOS basada 1:1 en el prototipo HTML `pichangaya-v4-final.html`.

## Mapa de pantallas (HTML → Flutter)

| HTML screen-id | Ruta Flutter | Archivo |
|---|---|---|
| screen-entry | /entry | auth/screens/entry_screen.dart |
| screen-client-login | /login | auth/screens/client_login_screen.dart |
| screen-client-register | /register | auth/screens/client_register_screen.dart |
| screen-login (admin) | /admin-login | auth/screens/admin_login_screen.dart |
| screen-client (4 tabs) | /home | cliente/screens/client_shell.dart |
| └ tab mapa | — | cliente/tabs/mapa_tab.dart |
| └ tab canchas | — | cliente/tabs/canchas_tab.dart |
| └ tab pagar | — | cliente/tabs/pagar_tab.dart |
| └ tab mis-reservas | — | cliente/tabs/mis_reservas_tab.dart |
| screen-admin (7 páginas) | /admin | admin/screens/admin_shell.dart |
| └ page-dashboard | — | admin/pages/admin_dashboard_page.dart |
| └ page-reservas | — | admin/pages/admin_reservas_page.dart |
| └ page-pagos-admin | — | admin/pages/admin_pagos_page.dart |
| └ page-clientes-admin | — | admin/pages/admin_clientes_page.dart |
| └ page-timers | — | admin/pages/admin_timers_page.dart |
| └ page-facturacion | — | admin/pages/admin_facturacion_page.dart |
| └ page-canchas-admin | — | admin/pages/admin_canchas_page.dart |

## Mapa de modales

| modal HTML | Archivo Flutter |
|---|---|
| modal-reserva | shared/modals/reserva_modal.dart |
| modal-pago | shared/modals/pago_modal.dart |
| modal-admin-confirmar | shared/modals/admin_confirmar_modal.dart |
| modal-factura | shared/modals/factura_modal.dart |
| modal-add-cancha | shared/modals/add_cancha_modal.dart |
| modal-voucher-zoom | shared/modals/voucher_zoom_modal.dart |

## Mapa de colores (CSS → Flutter)

| CSS variable | Flutter |
|---|---|
| --verde #00E676 | AppColors.verde |
| --negro #0A0F0D | AppColors.negro |
| --negro2 #111A14 | AppColors.negro2 |
| --negro3 #172119 | AppColors.negro3 |
| --card #192118 | AppColors.card |
| --texto #E8F5E0 | AppColors.texto |
| --texto2 #8FA888 | AppColors.texto2 |
| --azul #29B6F6 | AppColors.azul |
| --rojo #FF4444 | AppColors.rojo |

## Setup

```bash
flutter pub get
# Edita lib/core/constants/api_constants.dart con la URL del backend
flutter run
```

## Estructura
```
lib/
├── core/
│   ├── constants/   api_constants.dart, app_router.dart
│   └── theme/       app_colors.dart, app_theme.dart
├── features/
│   ├── auth/
│   │   └── screens/ entry, client_login, client_register, admin_login, splash
│   ├── cliente/
│   │   ├── screens/ client_shell.dart (topbar + 4 tabs)
│   │   └── tabs/    mapa, canchas, pagar, mis_reservas
│   └── admin/
│       ├── screens/ admin_shell.dart (sidebar + 7 páginas)
│       └── pages/   dashboard, reservas, pagos, clientes, timers, facturacion, canchas
└── shared/
    ├── api/         api_client.dart
    ├── models/      user, local, cancha, reserva, pago
    └── modals/      reserva, pago, admin_confirmar, factura, add_cancha, voucher_zoom
```
