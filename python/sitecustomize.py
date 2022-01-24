import site
import pathlib

here = pathlib.Path(__file__).parent
site.addsitedir(str(here))
