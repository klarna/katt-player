# Copyright 2013 Klarna AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

_ = require 'lodash'
LinearCheckEngine = require './linear-check'


module.exports = class LinearEngine extends LinearCheckEngine
  constructor: (scenarios, options = {}) ->
    return new LinearEngine(scenarios, options)  unless this instanceof LinearEngine
    options.check or= {}
    _.merge options,
      check:
        url: true
        method: true
        headers: false
        body: false
    super scenarios, options
