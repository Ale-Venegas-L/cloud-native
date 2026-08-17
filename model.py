from enum import Enum
from flask_sqlalchemy import SQLAlchemy

class TipoAlmacenamiento(Enum):
    SSD = "SSD"
    HDD = "HDD"
    HIBRIDO = "HIBRIDO"


db = SQLAlchemy()

class Computador(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(255), unique=True)
    cpu = db.Column(db.String(255), nullable=False)
    ram = db.Column(db.Integer, nullable=False)
    marca = db.Column(db.String(255),  nullable=False)

    tipo_almacenamiento = db.Column(db.Enum(TipoAlmacenamiento), nullable=False)
    capacidad_ssd = db.Column(db.Integer, default=0)
    capacidad_hdd = db.Column(db.Integer, default=0)

    def __init__(self, nombre: str, cpu: str, ram: int, marca: str,
                 tipo_almacenamiento: TipoAlmacenamiento,
                 capacidad_ssd: int = 0, capacidad_hdd: int = 0):
        self.nombre = nombre
        self.cpu = cpu
        self.ram = ram
        self.marca = marca
        self.tipo_almacenamiento = tipo_almacenamiento
        self.capacidad_ssd = capacidad_ssd
        self.capacidad_hdd = capacidad_hdd

    @property
    def almacenamiento_total(self):
        return self.capacidad_ssd + self.capacidad_hdd
    
    @property
    def es_hibrido(self):
        return self.capacidad_ssd > 0 and self.capacidad_hdd > 0