{% macro categorize_distance(distance_column, thresholds=[100, 500, 1000, 2000], labels=['Very Close', 'Close', 'Moderate', 'Far', 'Very Far']) %}
  case
    {% for threshold in thresholds %}
    when {{ distance_column }} <= {{ threshold }} then '{{ labels[loop.index0] }} (≤{{ threshold }}m)'
    {% endfor %}
    else '{{ labels[thresholds|length] }} (>{{ thresholds[-1] }}m)'
  end
{% endmacro %}
