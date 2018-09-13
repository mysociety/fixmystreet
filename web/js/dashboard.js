$(function(){
    if ($('html').is('.ie9')) {
        return;
    }

    Chart.defaults.global.defaultFontSize = 16;
    // Chart.defaults.global.defaultFontFamily = $('body').css('font-family');

    var colours = [
        '#FF4343', // red
        '#F4A140', // orange
        '#FFD000', // yellow
        '#62B356', // green
        '#4D96E5', // blue
        '#B446CA', // purple
        '#7B8B98', // gunmetal
        '#BCB590', // taupe
        '#9C0101', // dark red
        '#CA6D00', // dark orange
        '#C2A526', // dark yellow
        '#1D7710', // dark green
        '#1D64B1', // dark blue
        '#7A108F', // dark purple
        '#3B576E', // dark gunmetal
        '#655F3A'  // dark taupe
    ];

    var setUpLabelsForChart = function(chart){
        var $parent = $(chart.chart.canvas).parent();

        var lasty = 0;
        $.each(chart.config.data.datasets, function(datasetIndex, dataset){
            if (dataset.data.length == 0) {
                return;
            }
            var $label = $('.label[data-datasetIndex="' + datasetIndex + '"]', $parent);
            var latestPoint = chart.getDatasetMeta(datasetIndex).data[ dataset.data.length - 1 ];
            var y = latestPoint._model.y;
            if (y < lasty) {
                y = lasty;
            }
            $label.css({
                top: y
            });
            lasty = y + $label.height() + 8;
        });
    };

    // Returns an array `numberOfPoints` long, where the final item
    // is `radius`, and all the other items are 0.
    var pointRadiusFinalDot = function(numberOfPoints, radius){
        var pointRadius = [];
        for (var i=1; i < numberOfPoints; i++) {
            pointRadius.push(0);
        }
        pointRadius.push(radius);
        return pointRadius;
    };

    // Wraps a row label onto two equal equal lines,
    // if it is longer than 4 words.
    var linewrapLabel = function(text) {
        if ( text.split(' ').length < 5 ) {
            return text;
        }

        var middle = Math.floor(text.length / 2);
        var before = text.lastIndexOf(' ', middle);
        var after = text.indexOf(' ', middle + 1);

        if (before < after) {
            middle = after;
        } else {
            middle = before;
        }

        return [ text.substr(0, middle), text.substr(middle + 1) ];
    };

    var makeSparkline = function makeSparkline($el, valuesStr, color, title){
        var values = [];
        var labels = [];
        $.each(valuesStr.split(' '), function(key, value){
            values.push(Number(value));
            labels.push('');
        });
        var spread = Math.max.apply(null, values) - Math.min.apply(null, values);

        return new Chart($el, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    pointRadius: pointRadiusFinalDot(values.length, 4),
                    pointBackgroundColor: color,
                    borderColor: color,
                    lineTension: 0
                }]
            },
            options: {
                layout: {
                    padding: {
                        top: 0,
                        right: 5,
                        bottom: 0,
                        left: 2
                    }
                },
                scales: {
                    xAxes: [{
                        type: "category",
                        display: false
                    }],
                    yAxes: [{
                        type: "linear",
                        display: false,
                        ticks: {
                            min: Math.min.apply(null, values) - (spread * 0.3),
                            max: Math.max.apply(null, values) + (spread * 0.3)
                        }
                    }]
                }
            }
        });
    };

    $('.labelled-sparkline canvas').each(function(){
        makeSparkline(
            $(this),
            $(this).data('values'),
            $(this).data('color')
        );
    });

    $('#chart-all-reports').each(function(){
        var $allReports = $(this),
            labels = $allReports.data('labels'),
            data0 = $allReports.data('values-reports'),
            data1 = $allReports.data('values-fixed');

        var data = [{
              data: data0,
              pointRadius: pointRadiusFinalDot(data0.length, 4),
              pointBackgroundColor: colours[1],
              borderColor: colours[1]
        }];
        if ( data1 ) {
            data.push({
                    data: data1,
                    pointRadius: pointRadiusFinalDot(data1.length, 4),
                    pointBackgroundColor: colours[3],
                    borderColor: colours[3]
            });
        }

        window.chartAllReports = new Chart($allReports, {
            type: 'line',
            data: {
                labels: labels,
                datasets: data
            },
            options: {
                animation: {
                    onComplete: function(){
                        setUpLabelsForChart(this);
                    }
                },
                elements: {
                    line: {
                        cubicInterpolationMode: 'monotone'
                    }
                },
                layout: {
                    padding: {
                        top: 4
                    }
                },
                scales: {
                    xAxes: [{
                        type: 'category',
                        gridLines: {
                            display: false
                        }
                    }],
                    yAxes: [{
                        type: "linear",
                        ticks: {
                            display: false
                        }
                    }]
                },
                onResize: function(chart, size){
                    setUpLabelsForChart(chart);
                }
            }
        });
    });

    $('.js-make-bar-chart').each(function(){
        var $table = $(this);
        var $trs = $table.find('tr');
        var $wrapper = $('<div>').addClass('responsive-bar-chart').insertBefore($table);
        var canvasWidth = $table.attr('data-canvas-width') || 600;
        var rowHeight = $table.attr('data-row-height') || 30;
        var $canvas = $('<canvas>').attr({
            'width': canvasWidth,
            'height': rowHeight * $trs.length
        }).appendTo($wrapper);
        var rowLabels = [];
        var rowValues = [];

        $trs.each(function(){
            rowLabels.push( linewrapLabel($(this).find('th').text()) );
            rowValues.push( parseInt($(this).find('td').text(), 10) );
        });

        for (var l=colours.length, i=l; i<rowLabels.length; i++) {
            colours[i] = colours[i % l];
        }

        var barChart = new Chart($canvas, {
            type: 'horizontalBar',
            data: {
                labels: rowLabels,
                datasets: [{
                    label: "",
                    data: rowValues,
                    backgroundColor: colours
                }]
            },
            options: {
                animation: {
                    onComplete: function(){
                        // Label each bar with the numerical value.
                        var chartInstance = this.chart,
                            ctx = chartInstance.ctx;

                        ctx.font = Chart.helpers.fontString( Chart.defaults.global.defaultFontSize * 0.8, 'bold', Chart.defaults.global.defaultFontFamily);
                        ctx.textBaseline = 'middle';

                        this.data.datasets.forEach(function (dataset, i) {
                            var meta = chartInstance.controller.getDatasetMeta(i);
                            meta.data.forEach(function (bar, index) {
                                var dataValue = dataset.data[index];
                                var width_text = ctx.measureText(dataValue).width;
                                var width_bar = bar._model.x - bar._model.base;
                                var gutter = (bar._model.height - (Chart.defaults.global.defaultFontSize * 0.8)) / 2;
                                var textX;
                                if (width_text + 2 * gutter > width_bar) {
                                    textX = bar._model.x + gutter;
                                    ctx.textAlign = 'left';
                                    ctx.fillStyle = bar._model.backgroundColor;
                                } else {
                                    textX = bar._model.x - gutter;
                                    ctx.textAlign = 'right';
                                    ctx.fillStyle = '#fff';
                                }
                                ctx.fillText( dataValue, textX, bar._model.y );
                            });
                        });
                    }
                },
                scales: {
                    xAxes: [{
                        gridLines: {
                            drawBorder: false,
                            drawTicks: false
                        },
                        ticks: {
                            beginAtZero: true,
                            maxTicksLimit: 11,
                            display: false
                        }
                    }],
                    yAxes: [{
                        gridLines: {
                            display: false
                        }
                    }]
                }
            }
        });

        $table.hide();
    });
});
