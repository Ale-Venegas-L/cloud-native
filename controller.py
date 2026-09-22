from flask import Blueprint, jsonify, request
from model import db, Computador, TipoAlmacenamiento

api_bp = Blueprint('api', __name__, url_prefix='/api')


def to_dict(comp: Computador) -> dict:
    return {
        'id': comp.id,
        'nombre': comp.nombre,
        'cpu': comp.cpu,
        'ram': comp.ram,
        'marca': comp.marca,
        'tipo_almacenamiento': comp.tipo_almacenamiento.value,
        'capacidad_ssd': comp.capacidad_ssd,
        'capacidad_hdd': comp.capacidad_hdd,
        'almacenamiento_total': comp.almacenamiento_total,
        'es_hibrido': comp.es_hibrido,
    }


def parse_body(data: dict, instance: Computador | None = None) -> tuple[Computador | None, str | None]:
    required = ['nombre', 'cpu', 'ram', 'marca', 'tipo_almacenamiento']
    for field in required:
        if field not in data:
            return None, f'Campo requerido: {field}'
    try:
        TipoAlmacenamiento(data['tipo_almacenamiento'])
    except ValueError:
        return None, 'tipo_almacenamiento debe ser SSD, HDD o HIBRIDO'
    try:
        ram = int(data['ram'])
        ssd = int(data.get('capacidad_ssd', 0) or 0)
        hdd = int(data.get('capacidad_hdd', 0) or 0)
    except (TypeError, ValueError):
        return None, 'ram, capacidad_ssd y capacidad_hdd deben ser enteros'

    comp = instance or Computador(
        nombre='', cpu='', ram=0, marca='',
        tipo_almacenamiento=TipoAlmacenamiento.SSD,
    )
    comp.nombre = str(data['nombre']).strip()
    comp.cpu = str(data['cpu']).strip()
    comp.ram = ram
    comp.marca = str(data['marca']).strip()
    comp.tipo_almacenamiento = TipoAlmacenamiento(data['tipo_almacenamiento'])
    comp.capacidad_ssd = ssd
    comp.capacidad_hdd = hdd
    return comp, None


@api_bp.get('/computadores')
def listar():
    comps = Computador.query.order_by(Computador.id).all()
    return jsonify([to_dict(c) for c in comps]), 200


@api_bp.get('/computadores/<int:comp_id>')
def obtener(comp_id: int):
    comp = db.session.get(Computador, comp_id)
    if comp is None:
        return jsonify({'error': 'Computador no encontrado'}), 404
    return jsonify(to_dict(comp)), 200


@api_bp.post('/computadores')
def crear():
    data = request.get_json(silent=True) or {}
    comp, error = parse_body(data)
    if error:
        return jsonify({'error': error}), 400
    if Computador.query.filter_by(nombre=comp.nombre).first():
        return jsonify({'error': 'Ya existe un computador con ese nombre'}), 409
    db.session.add(comp)
    db.session.commit()
    return jsonify(to_dict(comp)), 201


@api_bp.put('/computadores/<int:comp_id>')
def actualizar(comp_id: int):
    comp = db.session.get(Computador, comp_id)
    if comp is None:
        return jsonify({'error': 'Computador no encontrado'}), 404
    data = request.get_json(silent=True) or {}
    updated, error = parse_body(data, instance=comp)
    if error:
        return jsonify({'error': error}), 400
    duplicado = Computador.query.filter(
        Computador.nombre == updated.nombre,
        Computador.id != comp_id,
    ).first()
    if duplicado:
        return jsonify({'error': 'Ya existe un computador con ese nombre'}), 409
    db.session.commit()
    return jsonify(to_dict(updated)), 200


@api_bp.delete('/computadores/<int:comp_id>')
def eliminar(comp_id: int):
    comp = db.session.get(Computador, comp_id)
    if comp is None:
        return jsonify({'error': 'Computador no encontrado'}), 404
    db.session.delete(comp)
    db.session.commit()
    return jsonify({'mensaje': 'Computador eliminado'}), 200
