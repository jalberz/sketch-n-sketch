# Implementation Notes for retarget-html Branch

The intent behind this document is to note all of the major changes we made to
the 'vanilla' Sketch-n-Sketch source to enable HTML output instead of SVG
output. Further, this document will hope 

## Target Goals

* Basically future objectives
* Insert further future objectives here
* Allow for flow / snapping zone interaction as seen in Javascript/SASS [Layout Grid](https://clippings.github.io/layout-grid/)

## Theory

In this section we explain each of the concepts we wanted to employ as well as the rationale behind each one.

#### Re-orient the Sketch-n-sketch SVG tool to Dorian, an HTML/CSS tool
1. Rationale:
	* The existing Sketch-n-sketch architecture opens up possibilities for manipulation of other file types

#### Rebuilt Basic Zone Implementation
1. Rationale:
	* Zones were originally implemented as Svg's, with the switch to Html, zones were switched as well.

#### Element Abstraction

1. Why do we need an element abstraction?
	* Since width & heights are known, useful abstractions such as Flows are possible
2. With Elements, we get a nice pipelined style for building styled html objects			```

#### Element Versions of HTML Nodes

* The general guidelines we've been following when it comes to defining the functions for each node type

* `width` and `height` arguments are always required
* Positioning is set to `absolute` by default

#### Flow

* What flow is meant to do
* The type of direct manipulation that we're aiming for

### CSS Pseudoselectors

* Why this is an issue
* The syntax we decided to go with

## Practice

This section explains the implementation details of the above concepts.

* For each section:
  * Relevant Functions
  * Caveats for said functions
  * Why any strangeness exists
  * What hasn't been implemented yet, but is/was intended to be

#### Re-orient the Sketch-n-sketch SVG tool to Dorian, an HTML/CSS tool
1. Implementation:
	* Retooled LangSvg.elm to LangHtml.elm, consisting mostly of:
		* Changing all functions arguments that dealt with Svg nodes to Html nodes
		* Changed buildSvg function to buildHtml (See InterfaceView2.elm line 125)
		* Changed display canvas to be an embedded iframe (See InterfaceView2.elm line 128)
2. Things left to implement:
	* See Zones

#### Rebuilt Basic Zone Implementation
1. Implementation:
	* Removed / Commented out existing zone implementation in the second half of InterfaceView2 & InterfaceController
	* Added new basic zone creation functions into InterfaceView2.elm (see lines ~212-270)
	* Basic Zones implemented for divs, imgs, tables.
2. Things left to implement:
	* Return of Color Zones and other slider-based zones

### Element Abstraction in Prelude
1. With Elements, we get a nice pipelined style for building styled html objects
	* One can invoke the element version of a function by using e + function (eDiv, eImg, eTable, etc.)
	* A width and a heigh must be provided to this function
		* arg order: width height (children or source)
	* This can then be pipelined to an element styling function (eStyle) with takes a list of key-value styles as arguments
		* Example:
			```
			; Three Divs
			(def threeDivsInt
			  (let [left0 top0 w h sep] [40 28 60 130 110]
			  (let divi (\i
			    (let lefti (+ left0 (* i sep))
			    (eStyle [ [ 'top'  top0  ]
			              [ 'left' lefti ]
			              [ 'background-color' 'lightblue' ] ]
			            (eDiv w h []) ) ) )
			  (basicDoc [] (map divi [0! 1! 2!])) ) ) )
			```

#### Element Versions of HTML Nodes

#### Implementations of Flow

### Collection of CSS Styles