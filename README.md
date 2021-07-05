# Decision Records Bash Script

A decision record is a record created each time a decision about a project is made. Based on the
principle of "Architectural Decision Records", this record typically holds a reference number,
record name, status, the context of the decision, the decision itself, and whether there are any
consequences that occur as a result.

## Implementation

This script has been created to extend the concept implemented with the 
[npryce/adr-tools][adr-tools], but to make it much more constrained, and to allow interoperable
and similarly testable code in various languages, including Python, Powershell and Javascript.

This script, in particular, draws a lot of inspiration with the npryce version, but has been
reimplemented, using BATS as a testing library, and has a much reduced footprint, when it comes to
the number of files created.

## License

This script is licensed under the GNU Lesser General Public License (GNU LGPL) version 3 or later.

[adr-tools]: https://github.com/npryce/adr-tools