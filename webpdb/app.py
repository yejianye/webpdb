import bottle
import os

static_root = os.path.join(os.path.dirname(__file__), 'static')
app = bottle.Bottle()

@app.route('/')
def root():
	return bottle.static_file('main.html', root=static_root)

@app.route('/static/<filepath:path>')
def serve_static(filepath):
	return bottle.static_file(filepath, root=static_root)

def run():
	bottle.run(app, host='0.0.0.0', port='16666')

if __name__ == '__main__':
	run()
