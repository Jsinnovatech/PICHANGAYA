# Importar todos los modelos para que Alembic los detecte automáticamente
# Si un modelo no está aquí, Alembic no lo incluye en las migraciones

from app.models.user import User
from app.models.local import Local
from app.models.cancha import Cancha
from app.models.horario import HorarioDisponible
from app.models.reserva import Reserva
from app.models.pago import Pago
from app.models.comprobante import Comprobante
from app.models.notificacion import Notificacion
from app.models.configuracion import Configuracion
from app.models.suscripcion import Suscripcion
from app.models.plan_config import PlanConfig