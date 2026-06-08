from flask import Flask, render_template
import pymysql

app = Flask(__name__)

@app.route('/')
def inicio():
    return render_template('inicio.html')


################rutas de productos#####################

@app.route('/productos')
def productos():
    return render_template('productos.html')

@app.route('/ventas')
def ventas():
    return render_template('ventas.html')

@app.route('/reportes')
def reporte():
    return render_template('reportes.html')

@app.route("/probar")
def probar_conexion():
    try:
        # 1. Intentar conectar a la base de datos
        conexion = pymysql.connect(
            host="localhost",
            database="inventario_ventas",
            user="root",
            password="Vm04300216*",
        )
        conexion.close()
        return "<h1>¡Conexión exitosa a Mysql! 🎉</h1>"

    except Exception as error:
        # 2. Si falla, muestra el error en la página
        return f"<h1>Error de conexión:</h1><p>{error}</p>"

if __name__ == '__main__':
    app.run(debug=True)