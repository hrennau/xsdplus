# xsdplus
A command-line tool for processing XSDs in various ways, e.g. generating location trees and treesheets.

Further tool operations generate fact trees (frequency trees and values tree). Fact trees give you a combined view on document model and actual use of the model by instance documents.

Use of this tool currently requires the use of the BaseX processor ( http://basex.org ).

Documention is under construction. For the time being, please consult doc/xsdplus-quickstart.pdf for getting started.

NOTICE (2017-11-07). Support for substitution groups has been added. Parameter "sgroupStyle" controls whether occurrences of a substitution group head are represented like a fully expanded choice of all group members (parameter value "expand"), if only a one-level, non-recursive expansion of the group members is performed (value "compact") or if the substitution group is ignored as such (value "ignore").