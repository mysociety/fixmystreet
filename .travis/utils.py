import hashlib
import os


def get_bundle_filename():
    root = os.path.join(os.path.dirname(__file__), '..')
    with open(os.path.join(root, 'cpanfile.snapshot')) as cpanfile:
        hash = hashlib.md5(cpanfile.read()).hexdigest()

    try:
        version = os.environ['TRAVIS_PERL_VERSION']
    except KeyError:
        # Not running on Travis, assume default Travis version
        version = '5.14'

    if version == '5.14':
        version = ''
    else:
        version = '-%s' % version

    filename = 'fixmystreet-local-%s%s.tgz' % (hash, version)
    return filename
