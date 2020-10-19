Version Changes
===============

0.3.4pre3
---------
* Update to publish Avvo gem to both Packagecloud and Artifactory
* Refactor CircleCi configuration to test with multiple Ruby versions.

0.1.6
-----
* Added a way to return spelling correction per word

0.1.5
------

* Move from GETs to POST to accommodate >4K query strings

0.1.0
-----
* Added local params to facets and filters (allows fq={!tag=dt})
	* Added support for facet field/query labels
	* Added support for tagging and excluding filters for facets
