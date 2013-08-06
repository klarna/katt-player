{
  _
  mockery
} = require './_utils'

exports.run = {}
exports.run.before = () ->
  # Mock file system
  fs = require 'fs'
  fsMock = _.cloneDeep fs
  fsMock.readFileSync = (filename) ->
    return fsTest1  if filename is '/mock/basic.apib'
    fs.readFileSync.apply fs, arguments
  fsMock.existsSync = (filename) ->
    return true  if filename is '/mock/basic.apib'
    fs.existsSync.apply fs, arguments
  fsMock.statSync = (filename) ->
    if filename is '/mock/basic.apib'
      return {
        isDirectory: () -> false
        isFile: () -> true
      }
    fs.statSync.apply fs, arguments
  mockery.registerMock 'fs', fsMock
  mockery.enable
    useCleanCache: true
    warnOnUnregistered: false
  {
    katt: require 'katt-js'
    kattPlayer: require '../'
  }


exports.run.after = () ->
  mockery.disable()
  mockery.deregisterAll()


fsTest1 = """--- Test 1 ---

---
Some description
---

# Step 1

The merchant creates a new example object on our server, and we respond with
the location of the created example.

POST /step1
> Accept: application/json
> Content-Type: application/json
> Cookie: katt_scenario=basic.apib
{
    "cart": {
        "items": [
            {
                "name": "Horse",
                "quantity": 1,
                "unit_price": 4495000
            },
            {
                "name": "Battery",
                "quantity": 4,
                "unit_price": 1000
            },
            {
                "name": "Staple",
                "quantity": 1,
                "unit_price": 12000
            }
        ]
    }
}
< 201
< Location: {{>example_uri}}


# Step 2

The client (customer) fetches the created resource data.

GET {{<example_uri}}
> Accept: application/json
> Cookie: katt_scenario=basic.apib, katt_transaction=1
< 200
< Content-Type: application/json
{
    "required_fields": [
        "email"
    ],
    "cart": "{{_}}"
}


# Step 3

The customer submits an e-mail address in the form.

POST {{<example_uri}}/step3
> Accept: application/json
> Content-Type: application/json
> Cookie: katt_scenario=basic.apib, katt_transaction=2
{
    "email": "test-customer@foo.klarna.com"
}
< 200
< Content-Type: application/json
{
    "required_fields": [
        "password"
    ],
    "cart": "{{_}}"
}


# Step 4

The customer submits the form again, this time also with his password.
We inform him that payment is required.

POST {{<example_uri}}/step4
> Accept: application/json
> Content-Type: application/json
> Cookie: katt_scenario=basic.apib, katt_transaction=3
{
    "email": "test-customer@foo.klarna.com",
    "password": "correct horse battery staple"
}
< 402
< Content-Type: application/json
{
    "error": "payment required"
}
"""
