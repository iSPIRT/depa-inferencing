# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_monitoring_dashboard" "environment_dashboard" {
  dashboard_json = <<EOF
{
  "displayName": "${var.environment} Inference Metrics",
  "mosaicLayout": {
    "columns": 48,
    "tiles": [
      {
        "height": 19,
        "widget": {
          "title": "system.cpu.percent [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.cpu.percent\" resource.type=\"generic_task\" metric.label.\"label\"!=\"total cpu cores\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 38
      },
      {
        "height": 19,
        "widget": {
          "title": "system.memory.usage_kb for main process [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.memory.usage_kb\" resource.type=\"generic_task\" metric.label.\"label\"=\"main process\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 57
      },
      {
        "height": 19,
        "widget": {
          "title": "system.memory.usage_kb for inference process [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.memory.usage_kb\" resource.type=\"generic_task\" metric.label.\"label\"=\"inference process\" metric.label.\"deployment_environment\"=\"${var.environment}\""
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 209
      },
      {
        "height": 19,
        "widget": {
          "title": "system.memory.usage_kb for MemAvailable: [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.memory.usage_kb\" resource.type=\"generic_task\" metric.label.\"label\"=\"MemAvailable:\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 57
      },
      {
        "height": 19,
        "widget": {
          "title": "system.thread.count [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.thread.count\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 76
      },
      {
        "height": 19,
        "widget": {
          "title": "system.cpu.total_cores [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/system.cpu.percent\" resource.type=\"generic_task\" metric.label.\"label\"=\"total cpu cores\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 76
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.count [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.count\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.duration_ms [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.duration_ms\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.size_bytes [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.size_bytes\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 19
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.response.size_bytes [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.response.size_bytes\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 19
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.failed_count_by_status [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.failed_count_by_status\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"status_code\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 38
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.errors_count [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.errors_count\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"error_code\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 133
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.count_by_model [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.count_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"model\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 95
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.duration_ms_by_model [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [
                        "metric.label.\"model\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.duration_ms_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 95
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.failed_count_by_model [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.failed_count_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"model\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 114
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.request.batch_count_by_model [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.request.batch_count_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")",
                    "secondaryAggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"model\"",
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 114
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.cloud_fetch.success_count [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.cloud_fetch.success_count\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 190
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.cloud_fetch.failed_count_by_status [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.cloud_fetch.failed_count_by_status\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 133
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_registration.recent_success_by_model [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_registration.recent_success_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 152
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_registration.failed_count_by_status [MEAN]",
          "xyChart": {
            "chartOptions": {},
             "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_registration.failed_count_by_status\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 152
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_registration.recent_failure_by_model [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_registration.recent_failure_by_model\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 171
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_registration.available_models [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_registration.available_models\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],

            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 171
      },
      {
        "height": 19,
        "widget": {
          "title": " bidding.inference.request.duration_ms [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/bidding.inference.request.duration_ms\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],
            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 190
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_deletion.success_count [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_deletion.success_count\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],

            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "xPos": 24,
        "yPos": 209
      },
      {
        "height": 19,
        "widget": {
          "title": "inference.model_deletion.failed_count_by_status [MEAN]",
          "xyChart": {
            "chartOptions": {},
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"service_name\"",
                        "metric.label.\"deployment_environment\"",
                        "metric.label.\"operator\"",
                        "metric.label.\"label\"",
                        "metric.label.\"Noise\"",
                        "resource.label.\"task_id\"",
                        "metric.label.\"service_version\""
                      ],
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/inference.model_deletion.failed_count_by_status\" resource.type=\"generic_task\" metric.label.\"deployment_environment\"=monitoring.regex.full_match(\"${var.environment}\")"
                  }
                }
              }
            ],

            "yAxis": {
              "scale": "LINEAR"
            }
          }
        },
        "width": 24,
        "yPos": 228
      }
    ]
    }
    }
EOF
}
