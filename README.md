# xsdplus
A command-line tool for processing XSDs in various ways, e.g. generating location trees and treesheets.

Further tool operations generate fact trees (frequency trees and values tree). Fact trees give you a combined view on document model and actual use of the model by instance documents.

Use of this tool currently requires the use of the BaseX processor ( http://basex.org ).

Documention is under construction. For the time being, please consult doc/xsdplus-quickstart.pdf for getting started.

IMPORTANT NOTICE (2017-06-10). Please be aware that currently substitution groups are not yet evaluated - the "choice groups", which they effectively imply, are still missing from location trees and resources derived from these. This will be amended in a few days.