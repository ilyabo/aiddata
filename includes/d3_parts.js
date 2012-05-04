d3 = {};

(function() {


  function d3_class(ctor, properties) {
    try {
      for (var key in properties) {
        Object.defineProperty(ctor.prototype, key, {
          value: properties[key],
          enumerable: false
        });
      }
    } catch (e) {
      ctor.prototype = properties;
    }
  }


  d3.map = function(object) {
    var map = new d3_Map;
    for (var key in object) map.set(key, object[key]);
    return map;
  };

  function d3_Map() {}

  d3_class(d3_Map, {
    has: function(key) {
      return d3_map_prefix + key in this;
    },
    get: function(key) {
      return this[d3_map_prefix + key];
    },
    set: function(key, value) {
      return this[d3_map_prefix + key] = value;
    },
    remove: function(key) {
      key = d3_map_prefix + key;
      return key in this && delete this[key];
    },
    keys: function() {
      var keys = [];
      this.forEach(function(key) { keys.push(key); });
      return keys;
    },
    values: function() {
      var values = [];
      this.forEach(function(key, value) { values.push(value); });
      return values;
    },
    entries: function() {
      var entries = [];
      this.forEach(function(key, value) { entries.push({key: key, value: value}); });
      return entries;
    },
    forEach: function(f) {
      for (var key in this) {
        if (key.charCodeAt(0) === d3_map_prefixCode) {
          f.call(this, key.substring(1), this[key]);
        }
      }
    }
  });

  var d3_map_prefix = "\0", // prevent collision with built-ins
      d3_map_prefixCode = d3_map_prefix.charCodeAt(0);


  d3.nest = (function() {
    var nest = {},
        keys = [],
        sortKeys = [],
        sortValues,
        rollup;

    function map(array, depth) {
      if (depth >= keys.length) return rollup
          ? rollup.call(nest, array) : (sortValues
          ? array.sort(sortValues)
          : array);

      var i = -1,
          n = array.length,
          key = keys[depth++],
          keyValue,
          object,
          valuesByKey = new d3_Map,
          values,
          o = {};

      while (++i < n) {
        if (values = valuesByKey.get(keyValue = key(object = array[i]))) {
          values.push(object);
        } else {
          valuesByKey.set(keyValue, [object]);
        }
      }

      valuesByKey.forEach(function(keyValue) {
        o[keyValue] = map(valuesByKey.get(keyValue), depth);
      });

      return o;
    }

    function entries(map, depth) {
      if (depth >= keys.length) return map;

      var a = [],
          sortKey = sortKeys[depth++],
          key;

      for (key in map) {
        a.push({key: key, values: entries(map[key], depth)});
      }

      if (sortKey) a.sort(function(a, b) {
        return sortKey(a.key, b.key);
      });

      return a;
    }

    nest.map = function(array) {
      return map(array, 0);
    };

    nest.entries = function(array) {
      return entries(map(array, 0), 0);
    };

    nest.key = function(d) {
      keys.push(d);
      return nest;
    };

    // Specifies the order for the most-recently specified key.
    // Note: only applies to entries. Map keys are unordered!
    nest.sortKeys = function(order) {
      sortKeys[keys.length - 1] = order;
      return nest;
    };

    // Specifies the order for leaf values.
    // Applies to both maps and entries array.
    nest.sortValues = function(order) {
      sortValues = order;
      return nest;
    };

    nest.rollup = function(f) {
      rollup = f;
      return nest;
    };

    return nest;
  });


})();
