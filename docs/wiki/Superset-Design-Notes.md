SuperSet is a web based data visualization framework with a focus on performance rather than design.  As such, it does not contain the same ability, out of the box, to create custom layouts in the same way that the PowerBI dashboard builder enables.  As an open source project, Superset can of course be completely customized. However, this page considers design considerations/limitations for implementing superset "as is".

### Known Bug:  Color Scheme Application
Superset automatically applies selected color scheme to chart series at time of dashboard load.  This usually works very well.  However, color schemes sometimes apply the same color multiple times within a chart.  The bug is documented [here](https://github.com/apache/superset/issues/26437) and [here](https://github.com/apache/superset/issues/33115).  It is possible to work around this by hard coding colors for specific series under Advanced Settings.  `Edit Dashboard => Edit Properties => Advanced`.  Add desired colors to the JSON string as follows:
```
"label_colors": {
    "Asian": "#FF6726",
    "None": "#902687",
    "RetainedDistrictAndSchool": "#02215D",
    "NoLongerInCounty": "#BD7150",
    "RetainedDistrictNotSchool": "#B687AC"
  },
```
*Replace series names and colors with desired ones.  **Note:  Hard coding colors will result in unexpected behavior if series data changes.  Use with caution.**

### Series on Horizontal Axes
Unlike PowerBI, Superset requires that every bar chart has a primary axis defined.  Further, the column used for the primary axis cannot be the same as the column used in the dimension (to break series out by color).  This means that bar charts can only be monochrome.  To achieve a bar chart broken out by color, create a calculated column that has a different name as the primary axis column but has value of the primary dimension column.  This is essentially a duplicate column, which can be used to achieve the goal.

### Representing Percentages in Bar charts
In Superset, bar charts by default are set up to show amount, not percentage.  Percentage breakdown can only be achieved by sticking to the monochrome bar chart.


