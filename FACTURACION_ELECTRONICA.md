# Integración Facturación Electrónica — PichangaYa
> Guía completa paso a paso para integrar SUNAT via Nubefact

---

## 1. Contexto: cómo funciona la cadena

```
Cliente paga → Admin aprueba pago → Sistema emite comprobante → SUNAT lo registra
```

SUNAT no recibe los comprobantes directamente desde tu app. El flujo real es:

```
Tu backend (FastAPI)
    → Nubefact (OSE — Operador de Servicios Electrónicos)
        → SUNAT (validación y registro oficial)
            → Nubefact te devuelve el CDR (Constancia de Recepción)
                → Tu backend guarda el resultado en la tabla comprobantes
```

**Nubefact** actúa como intermediario autorizado por SUNAT. Ellos se encargan del
XML firmado, el certificado digital y la comunicación con SUNAT. Tú solo les mandas
un JSON con los datos del comprobante.

---

## 2. Lo que tu amigo debe darte

Cuando te entregue el acceso a la API de Nubefact, necesitas exactamente esto:

| Dato | Dónde se usa |
|------|--------------|
| **RUC de la empresa** | En cada request a Nubefact |
| **API Token de Nubefact** | Header `Authorization` |
| **Serie de boletas** | Ej: `B001` (empieza en 1, incrementa) |
| **Serie de facturas** | Ej: `F001` (empieza en 1, incrementa) |
| **Modo** | `demo` (pruebas) o `produccion` |
| **URL base** | `https://api.nubefact.com/api/v1` (produccion) |

### Variables de entorno que hay que agregar al `.env` de Railway:

```env
NUBEFACT_URL=https://api.nubefact.com/api/v1
NUBEFACT_TOKEN=tu_token_aqui
NUBEFACT_RUC=20XXXXXXXXX
NUBEFACT_SERIE_BOLETA=B001
NUBEFACT_SERIE_FACTURA=F001
```

---

## 3. Estructura de la base de datos (ya existe)

El modelo `Comprobante` ya está creado en `backend/app/models/comprobante.py`.
Campos relevantes:

```python
# Lo que ya tienes
id                  # UUID
reserva_id          # FK a reservas
serie               # "B001" o "F001"
numero              # correlativo (1, 2, 3...)
estado              # pendiente | emitido | error
pdf_url             # URL del PDF que devuelve Nubefact
xml_url             # URL del XML firmado
nubefact_id         # ID del comprobante en Nubefact
created_at
```

**Si falta algún campo**, agrégalo con una migración Alembic:
```bash
alembic revision --autogenerate -m "add nubefact fields to comprobantes"
alembic upgrade head
```

---

## 4. Lógica del número correlativo

SUNAT exige que el número sea secuencial y sin saltos. La forma segura:

```python
# En el momento de emitir, consultar el último número de esa serie
ultimo = await db.execute(
    select(func.max(Comprobante.numero))
    .where(Comprobante.serie == serie)
)
siguiente_numero = (ultimo.scalar() or 0) + 1
```

> Nunca guardes el correlativo en una variable global ni en `.env`.
> Siempre calcularlo desde la BD para evitar duplicados si el servidor se reinicia.

---

## 5. Payload que envías a Nubefact

### 5.1 Boleta de Venta (tipo_comprobante = "03")

```json
{
    "operacion": "generar_comprobante",
    "tipo_de_comprobante": 3,
    "serie": "B001",
    "numero": 1,
    "sunat_transaction": 1,
    "cliente_tipo_de_documento": 1,
    "cliente_numero_de_documento": "12345678",
    "cliente_denominacion": "Juan Pérez García",
    "cliente_direccion": "",
    "cliente_email": "",
    "fecha_de_emision": "21-04-2026",
    "fecha_de_vencimiento": "",
    "moneda": 1,
    "tipo_de_cambio": "",
    "porcentaje_de_igv": 18.0,
    "descuento_global": "",
    "total_descuento": "",
    "total_anticipo": "",
    "total_gravada": 84.75,
    "total_inafecta": "",
    "total_exonerada": "",
    "total_igv": 15.25,
    "total_gratuita": "",
    "total_otros_cargos": "",
    "total": 100.00,
    "percepcion_tipo": "",
    "percepcion_base_imponible": "",
    "total_percepcion": "",
    "total_incluido_percepcion": "",
    "detraccion": false,
    "observaciones": "Reserva cancha sintética PichangaYa",
    "documento_que_se_modifica_tipo": "",
    "documento_que_se_modifica_serie": "",
    "documento_que_se_modifica_numero": "",
    "tipo_de_nota_de_credito": "",
    "tipo_de_nota_de_debito": "",
    "enviar_automaticamente_a_la_sunat": true,
    "enviar_automaticamente_al_cliente": false,
    "codigo_unico": "RES-XXXXXX",
    "condiciones_de_pago": "",
    "medio_de_pago": "Transferencia",
    "placa_vehiculo": "",
    "orden_compra_servicio": "",
    "tabla_personalizada_codigo": "",
    "formato_de_pdf": "",
    "items": [
        {
            "unidad_de_medida": "ZZ",
            "codigo": "CANCHA-001",
            "descripcion": "Alquiler Cancha Sintética — Cancha Norte 1h",
            "cantidad": 1,
            "valor_unitario": 84.75,
            "precio_unitario": 100.00,
            "descuento": "",
            "subtotal": 84.75,
            "tipo_de_igv": 1,
            "igv": 15.25,
            "total": 100.00,
            "anticipo_regularizacion": false,
            "anticipo_documento_serie": "",
            "anticipo_documento_numero": ""
        }
    ]
}
```

### 5.2 Factura (tipo_comprobante = "01")

Igual que boleta pero con estos cambios:
```json
{
    "tipo_de_comprobante": 1,
    "serie": "F001",
    "cliente_tipo_de_documento": 6,
    "cliente_numero_de_documento": "20XXXXXXXXX",
    "cliente_denominacion": "Empresa SAC"
}
```

> Para boleta: `tipo_de_documento = 1` (DNI) o `4` (carnet extranjería)
> Para factura: `tipo_de_documento = 6` (RUC obligatorio)

### 5.3 Cálculo del IGV (18%)

```python
# El precio_total de la reserva ya incluye IGV (precio con IGV)
precio_con_igv = float(reserva.precio_total)    # Ej: 100.00
base_imponible = round(precio_con_igv / 1.18, 2)  # Ej: 84.75
igv = round(precio_con_igv - base_imponible, 2)   # Ej: 15.25
```

---

## 6. Código del servicio Nubefact

Crear el archivo `backend/app/services/nubefact.py`:

```python
import httpx
from datetime import date
from app.core.config import settings

TIPO_DOC_BOLETA  = 3
TIPO_DOC_FACTURA = 1


async def emitir_comprobante(
    *,
    tipo: str,          # "boleta" o "factura"
    serie: str,         # "B001" o "F001"
    numero: int,
    cliente_nombre: str,
    cliente_doc_tipo: int,  # 1=DNI, 6=RUC
    cliente_doc_numero: str,
    monto_total: float,
    cancha_nombre: str,
    reserva_codigo: str,
    metodo_pago: str,
    fecha: date | None = None,
) -> dict:
    """
    Envía el comprobante a Nubefact y retorna la respuesta completa.
    Lanza httpx.HTTPStatusError si Nubefact responde con error.
    """
    if fecha is None:
        fecha = date.today()

    base_imponible = round(monto_total / 1.18, 2)
    igv = round(monto_total - base_imponible, 2)

    payload = {
        "operacion": "generar_comprobante",
        "tipo_de_comprobante": TIPO_DOC_BOLETA if tipo == "boleta" else TIPO_DOC_FACTURA,
        "serie": serie,
        "numero": numero,
        "sunat_transaction": 1,
        "cliente_tipo_de_documento": cliente_doc_tipo,
        "cliente_numero_de_documento": cliente_doc_numero,
        "cliente_denominacion": cliente_nombre,
        "cliente_direccion": "",
        "cliente_email": "",
        "fecha_de_emision": fecha.strftime("%d-%m-%Y"),
        "moneda": 1,
        "porcentaje_de_igv": 18.0,
        "total_gravada": base_imponible,
        "total_igv": igv,
        "total": monto_total,
        "observaciones": f"Reserva cancha sintética PichangaYa — {reserva_codigo}",
        "enviar_automaticamente_a_la_sunat": True,
        "enviar_automaticamente_al_cliente": False,
        "codigo_unico": reserva_codigo,
        "medio_de_pago": metodo_pago,
        "items": [
            {
                "unidad_de_medida": "ZZ",
                "codigo": "CANCHA-001",
                "descripcion": f"Alquiler {cancha_nombre}",
                "cantidad": 1,
                "valor_unitario": base_imponible,
                "precio_unitario": monto_total,
                "subtotal": base_imponible,
                "tipo_de_igv": 1,
                "igv": igv,
                "total": monto_total,
                "anticipo_regularizacion": False,
            }
        ],
    }

    url = f"{settings.NUBEFACT_URL}/{settings.NUBEFACT_RUC}/invoices"
    headers = {
        "Authorization": f"Token token={settings.NUBEFACT_TOKEN}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()
```

---

## 7. Agregar las variables al config

En `backend/app/core/config.py`, agregar:

```python
# Facturación electrónica
NUBEFACT_URL: str = "https://api.nubefact.com/api/v1"
NUBEFACT_TOKEN: str = ""
NUBEFACT_RUC: str = ""
NUBEFACT_SERIE_BOLETA: str = "B001"
NUBEFACT_SERIE_FACTURA: str = "F001"
```

---

## 8. Endpoint de emisión en el router de admin

En `backend/app/routers/admin.py`, agregar este endpoint:

```python
from app.services.nubefact import emitir_comprobante
from app.models.comprobante import Comprobante, EstadoComprobanteEnum

@router.post("/facturacion/{reserva_id}/emitir")
async def admin_emitir_comprobante(
    reserva_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    # 1. Buscar la reserva
    reserva = (await db.execute(
        select(Reserva).where(Reserva.id == reserva_id)
    )).scalar_one_or_none()
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    # 2. Verificar que el pago esté verificado
    pago = (await db.execute(
        select(Pago).where(
            Pago.reserva_id == reserva_id,
            Pago.estado == EstadoPagoEnum.verificado
        )
    )).scalar_one_or_none()
    if not pago:
        raise HTTPException(status_code=400, detail="El pago aún no está verificado")

    # 3. Verificar que no tenga comprobante ya emitido
    comp_existente = (await db.execute(
        select(Comprobante).where(
            Comprobante.reserva_id == reserva_id,
            Comprobante.estado == EstadoComprobanteEnum.emitido
        )
    )).scalar_one_or_none()
    if comp_existente:
        raise HTTPException(status_code=400, detail="Ya existe un comprobante emitido para esta reserva")

    # 4. Determinar serie y tipo
    es_factura = reserva.tipo_doc and reserva.tipo_doc.value == "factura"
    serie = settings.NUBEFACT_SERIE_FACTURA if es_factura else settings.NUBEFACT_SERIE_BOLETA

    # 5. Calcular número correlativo (siempre desde BD)
    ultimo_num = (await db.execute(
        select(func.max(Comprobante.numero)).where(Comprobante.serie == serie)
    )).scalar() or 0
    siguiente = ultimo_num + 1

    # 6. Datos del cliente
    cliente = (await db.execute(
        select(User).where(User.id == reserva.cliente_id)
    )).scalar_one_or_none()
    cancha = (await db.execute(
        select(Cancha).where(Cancha.id == reserva.cancha_id)
    )).scalar_one_or_none()

    # Para boleta: usar DNI si lo tiene, sino "00000000"
    doc_tipo   = 6 if es_factura else 1
    doc_numero = cliente.dni if (cliente and cliente.dni) else "00000000"

    # 7. Crear registro en BD con estado "pendiente" antes de llamar a Nubefact
    comprobante = Comprobante(
        id=uuid.uuid4(),
        reserva_id=reserva_id,
        serie=serie,
        numero=siguiente,
        estado=EstadoComprobanteEnum.pendiente,
    )
    db.add(comprobante)
    await db.flush()  # reserva el número correlativo

    # 8. Llamar a Nubefact
    try:
        resultado = await emitir_comprobante(
            tipo="factura" if es_factura else "boleta",
            serie=serie,
            numero=siguiente,
            cliente_nombre=cliente.nombre if cliente else "Cliente",
            cliente_doc_tipo=doc_tipo,
            cliente_doc_numero=doc_numero,
            monto_total=float(reserva.precio_total),
            cancha_nombre=cancha.nombre if cancha else "Cancha",
            reserva_codigo=reserva.codigo,
            metodo_pago=pago.metodo.value,
        )
        # 9. Guardar resultado exitoso
        comprobante.estado   = EstadoComprobanteEnum.emitido
        comprobante.pdf_url  = resultado.get("enlace_del_pdf")
        comprobante.xml_url  = resultado.get("enlace_del_xml")
        comprobante.nubefact_id = str(resultado.get("numero_de_ticket", ""))
        await db.commit()

        return {
            "mensaje": f"Comprobante {serie}-{str(siguiente).zfill(5)} emitido correctamente",
            "serie": serie,
            "numero": siguiente,
            "pdf_url": comprobante.pdf_url,
        }

    except Exception as e:
        # 10. Marcar como error pero NO hacer rollback del número
        # (SUNAT puede haberlo registrado aunque haya fallado la respuesta)
        comprobante.estado = EstadoComprobanteEnum.error
        await db.commit()
        raise HTTPException(
            status_code=502,
            detail=f"Error al emitir comprobante en Nubefact: {str(e)}"
        )
```

---

## 9. Botón en el panel de Facturación (Flutter)

En `admin_facturacion_page.dart`, cada fila que tenga `comprobante_estado == null`
debe mostrar un botón "Emitir":

```dart
// En el card de cada item de facturación
if (item['comprobante_estado'] == null) ...[
  GestureDetector(
    onTap: () => _emitirComprobante(item['reserva_id']),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.verde.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.verde.withOpacity(0.4)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long, color: AppColors.verde, size: 13),
        SizedBox(width: 5),
        Text('Emitir', style: TextStyle(color: AppColors.verde, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  ),
] else if (item['comprobante_estado'] == 'emitido') ...[
  // Botón descargar PDF
  GestureDetector(
    onTap: () => _abrirPdf(item['pdf_url']),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.azul.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.azul.withOpacity(0.4)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.picture_as_pdf, color: AppColors.azul, size: 13),
        SizedBox(width: 5),
        Text('PDF', style: TextStyle(color: AppColors.azul, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  ),
],

// Métodos:
Future<void> _emitirComprobante(String reservaId) async {
  try {
    final res = await ApiClient().dio.post('/admin/facturacion/$reservaId/emitir');
    _cargar(); // recargar la lista
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${res.data['mensaje']}'),
      backgroundColor: const Color(0xFF1B5E20),
    ));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Error al emitir comprobante'),
      backgroundColor: AppColors.rojo,
    ));
  }
}

Future<void> _abrirPdf(String? url) async {
  if (url == null) return;
  // Usar url_launcher: await launchUrl(Uri.parse(url))
}
```

---

## 10. Flujo completo resumido

```
1. Cliente hace reserva (elige boleta o factura)
2. Cliente sube voucher de pago
3. Admin aprueba el pago → reserva queda en "confirmed"
4. Admin va al tab Facturación
5. Admin ve la fila con botón "Emitir"
6. Admin presiona "Emitir" → backend llama a Nubefact → SUNAT registra
7. Nubefact devuelve PDF y XML
8. El botón "Emitir" cambia a "PDF" (descargable)
9. El cliente puede ver el comprobante en "Mis Reservas" (serie_fact)
```

---

## 11. Datos que el cliente necesita dar para factura

Para emitir una **factura** (no boleta) el cliente debe proporcionar:
- RUC de la empresa (11 dígitos)
- Razón social

Esto implica que en el flujo de reserva, cuando el cliente elige "factura",
debería aparecer un formulario adicional para capturar esos datos.
Actualmente no está implementado en el frontend. Se puede agregar al
`ReservaCreateRequest` con campos opcionales `ruc_factura` y `razon_social`.

---

## 12. Entorno de pruebas (demo)

Nubefact tiene un entorno de pruebas:
- URL demo: `https://api.nubefact.com/api/v1` (mismo endpoint, diferente token)
- Los comprobantes emitidos en modo demo no van a SUNAT real
- Tu amigo debe darte un token de demo primero para probar

Para probar sin DNI real puedes usar `00000000` en boletas (SUNAT lo acepta
para ventas menores a 700 soles sin identificar al cliente).

---

## 13. Checklist antes de activar en producción

- [ ] Token de Nubefact configurado en Railway (variable de entorno)
- [ ] RUC de la empresa configurado
- [ ] Series iniciales definidas (B001 / F001)
- [ ] Probado en entorno demo con al menos 3 comprobantes
- [ ] Verificar que los PDFs se abren correctamente
- [ ] Endpoint `/admin/facturacion/{id}/emitir` funciona
- [ ] Botón "Emitir" en el panel Flutter funcionando
- [ ] Para facturas: formulario de RUC/razón social en el flujo de reserva
- [ ] Manejo de errores: qué pasa si Nubefact está caído (estado "error" en BD)

---

## 14. Dependencias de Python a agregar

```bash
pip install httpx
```

Agregar al `requirements.txt`:
```
httpx==0.27.0
```

> `httpx` es la librería para hacer requests HTTP async en FastAPI.
> Si ya la tienen instalada (posible porque es dependencia de otros paquetes), verificar con `pip show httpx`.
