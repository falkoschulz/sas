// VARIABLES
var taille = 1.5;

var margin = {top: 25, right: 25, bottom: 25, left: 25},
    padding = 0,
    width = ($(document).width() - margin.left - margin.right),
    height = ($(document).height() - margin.top - margin.bottom);

var force = d3.layout.force()
    .charge(0)
    .gravity(0)
    .size([width, height]);

var svg = d3.select("#carte").append("svg")
    .attr("width", width)
    .attr("height", height);

var arr = Array();

// FUNCTIONS
function allGraph(maxValue, ratio, scale, results) {
    $.getJSON('centroids/centroid-country.json', function (data) {
        // debugger;

        // basic validation
        $.each(results.data, function (index, row) {
            var resultsRow = data.features.filter( function(value) {
                var country = value.properties.name;
                return country.indexOf(row["country"]) != -1;
            });
            if (resultsRow.length === 0) {
                console.error("No match found for " + row["country"]);
            }
        });

        $.each(data.features, function (index, value) {
            var country = value.properties.name;
            var resultsRow = results.data.filter( function(row) {
                return country.indexOf(row["country"]) != -1;
            });

            var color = null;
            var size = null;
            if (resultsRow.length > 0) {
                color = resultsRow[0]["color"];
                size = resultsRow[0]["size"];
            }else{
                // console.error("No match found for " + country);
            }
            if (color === null || color === undefined || isNaN(color) || color < 1) color = 1;
            if (size === null || size === undefined || isNaN(size) || size < 1) size = 1;

            arr.push([value.id, size, color]);
        });

        var projection = d3.geo.equirectangular()
            .scale(scale * taille) //default 114
            .translate([width / 2, height / 2]);

        var radius = d3.scale.sqrt()
            .domain([0, maxValue / 100]) // MAX value ratio OR todo: "d3.max(value)"  ||  16.5 / 100 = .165 
            .range([0, 30]);

        graph(radius, ratio, projection, results);
    });
}

function graph(radius, ratio, projection, results) {
    d3.json("centroids/centroid-country.json", function (error, states) {
        if (error) throw error;

        var nodes = states.features
            .map(function (d) {
                var size = d.properties.value;
                var color = d.properties.value;

                arr.forEach(function (element, index, array) {
                    if (d.id == element[0]) {
                        size = element[1] * 6;
                        color = element[2];
                    }
                });

                size += 1;

                var point = projection(d.geometry.coordinates),
                    title = "<b>" + d.properties.name + "</b><br/>Size: " + size + "<br/>Color: " + color;

                return {
                    x: point[0], y: point[1],
                    x0: point[0], y0: point[1],
                    r: radius(size / ratio) * taille,
                    title: title,
                    color: color
                };
            });

        force
            .nodes(nodes)
            .on("tick", tick)
            .start();

        // Define the div for the tooltip
        var div = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0);

        var node = svg.selectAll("rect")
            .data(nodes)
            .enter().append("rect")
            .attr("width", function (d) {
                return (d.r * 2);
            })
            .attr("height", function (d) {
                return (d.r * 2);
            })
            .each(function () {
                d3.select(this).attr("fill", function (d) {
                    return getColorFromValue(d.color);
                });
                d3.select(this).attr("title", function (d) {
                    return d.title;
                });
            }).on("mouseover", function(d) {
                div.transition()
                    .duration(200)
                    .style("opacity", .9);
                div.html(d.title)
                    .style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY - 28) + "px");
            })
            .on("mousemove", function () {
                div.style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY - 28) + "px");
            })
            .on("mouseout", function(d) {
                div.transition()
                    .duration(500)
                    .style("opacity", 0);
            });

        // FUNCTION OF GRAPH()
        function tick(e) {
            node.each(gravity(e.alpha * .1))
                .each(collide(.5))
                .attr("x", function (d) {
                    return (d.x - d.r);
                })
                .attr("y", function (d) {
                    return (d.y - d.r);
                });
        }

        function gravity(k) {
            return function (d) {
                d.x += (d.x0 - d.x) * k;
                d.y += (d.y0 - d.y) * k;
            };
        }

        function collide(k) {
            var q = d3.geom.quadtree(nodes);
            return function (node) {
                var nr = node.r + padding,
                    nx1 = node.x - nr,
                    nx2 = node.x + nr,
                    ny1 = node.y - nr,
                    ny2 = node.y + nr;
                q.visit(function (quad, x1, y1, x2, y2) {
                    if (quad.point && (quad.point !== node)) {
                        var x = node.x - quad.point.x,
                            y = node.y - quad.point.y,
                            lx = Math.abs(x),
                            ly = Math.abs(y),
                            r = nr + quad.point.r;
                        if (lx < r && ly < r) {
                            if (lx > ly) {
                                lx = (lx - r) * (x < 0 ? -k : k);
                                node.x -= lx;
                                quad.point.x += lx;
                            } else {
                                ly = (ly - r) * (y < 0 ? -k : k);
                                node.y -= ly;
                                quad.point.y += ly;
                            }
                        }
                    }
                    return x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1;
                });
            };
        }

        // FUNCTION IN INDEX.HTML
        // function getColorFromValue(value) {
        //   if (value > 10) {
        //       return "#B12535";
        //   } else if (value > 5) {
        //       return "#D76D43";
        //   } else if (value > 0) {
        //       return "#EFC46E";
        //   } else {
        //       return "#ECECED";
        //   }
        // }

    });
}