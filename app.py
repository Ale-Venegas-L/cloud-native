import os

from flask import Flask, send_from_directory

from model import db
from controller import api_bp

app = Flask(__name__, static_folder='static', static_url_path='')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 'sqlite:///computadores.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)
app.register_blueprint(api_bp)


@app.get('/')
def spa():
    return send_from_directory(app.static_folder, 'index.html')


@app.get('/<path:path>')
def static_files(path: str):
    return send_from_directory(app.static_folder, path)


with app.app_context():
    db.create_all()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8000)), debug=True)
