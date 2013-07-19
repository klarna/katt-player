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
< Location: /step2


# Step 2

The client (customer) fetches the created resource data.

GET /step2
> Accept: application/json
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

POST /step3
> Accept: application/json
> Content-Type: application/json
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

POST /step4
> Accept: application/json
> Content-Type: application/json
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
