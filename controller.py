from flask import Blueprint, render_template, request, redirect, url_for
from model import db, Computador, TipoAlmacenamiento

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    computadores = Computador.query.all()
    return render_template('index.html', computadores=computadores)

@main_bp.route('/crear', methods=['GET', 'POST'])
def crear():
    if request.method == 'POST':
        comp = Computador(
            nombre=request.form['nombre'],
            cpu=request.form['cpu'],
            ram=int(request.form['ram']),
            marca=request.form['marca'],
            tipo_almacenamiento=TipoAlmacenamiento(request.form['tipo_almacenamiento']),
            capacidad_ssd=int(request.form.get('capacidad_ssd', 0)),
            capacidad_hdd=int(request.form.get('capacidad_hdd', 0))
        )
        db.session.add(comp)
        db.session.commit()
        return redirect(url_for('main.index'))
    return render_template('crear.html')

@main_bp.route('/editar/<int:id>', methods=['GET', 'POST'])
def editar(id):
    comp = Computador.query.get_or_404(id)
    if request.method == 'POST':
        comp.nombre = request.form['nombre']
        comp.cpu = request.form['cpu']
        comp.ram = int(request.form['ram'])
        comp.marca = request.form['marca']
        comp.tipo_almacenamiento = TipoAlmacenamiento(request.form['tipo_almacenamiento'])
        comp.capacidad_ssd = int(request.form.get('capacidad_ssd', 0))
        comp.capacidad_hdd = int(request.form.get('capacidad_hdd', 0))
        db.session.commit()
        return redirect(url_for('main.index'))
    return render_template('editar.html', comp=comp, tipos=TipoAlmacenamiento)

@main_bp.route('/eliminar/<int:id>', methods=['POST'])
def eliminar(id):
    comp = Computador.query.get_or_404(id)
    db.session.delete(comp)
    db.session.commit()
    return redirect(url_for('main.index'))