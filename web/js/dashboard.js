$(function(){

    Chart.defaults.global.defaultFontSize = 16;
    Chart.defaults.global.defaultFontFamily = $('body').css('font-family');

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
        var xGutterInPixels = 30;

        var lasty = 0;
        $.each(chart.config.data.datasets, function(datasetIndex, dataset){
            var $label = $('.label[data-datasetIndex="' + datasetIndex + '"]', $parent);
            var latestPoint = chart.getDatasetMeta(datasetIndex).data[ dataset.data.length - 1 ];
            var y = latestPoint._model.y;
            if (y < lasty) {
                y = lasty;
            }
            $label.css({
                top: y,
                left: latestPoint._model.x + xGutterInPixels
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

        window.chartAllReports = new Chart($allReports, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: data0,
                    pointRadius: pointRadiusFinalDot(data0.length, 4),
                    pointBackgroundColor: colours[1],
                    borderColor: colours[1]
                }, {
                    data: data1,
                    pointRadius: pointRadiusFinalDot(data1.length, 4),
                    pointBackgroundColor: colours[3],
                    borderColor: colours[3]
                }]
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
        var $canvas = $('<canvas>').attr({
            'width': 600,
            'height': 30 * $trs.length
        }).appendTo($wrapper);
        var rowLabels = [];
        var rowValues = [];

        $trs.each(function(){
            rowLabels.push( $(this).find('th').text() );
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
                        ctx.textAlign = 'right';
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
                                    textX = bar._model.x + 2 * gutter;
                                    ctx.fillStyle = bar._model.backgroundColor;
                                } else {
                                    textX = bar._model.x - gutter;
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
