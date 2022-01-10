local cjson   = require "cjson"
local helpers = require "spec.helpers"
local Errors  = require "kong.db.errors"

local PLUGIN_NAME = "weighted-rate-limiter"

for _, strategy in ipairs({ "postgres" }) do
  describe("Plugin: rate-limiting (API) [#" .. strategy .. "]", function()
    local admin_client
    local bp

    lazy_setup(function()
      bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })
    end)

    lazy_teardown(function()
      if admin_client then
        admin_client:close()
      end

      helpers.stop_kong(nil, true)
    end)

    describe("POST", function()
      local route

      lazy_setup(function()

        route = bp.routes:insert {
          hosts      = { "test1.com" },
          protocols  = { "http", "https" },
          service    = service
        }

        -- start kong
        assert(helpers.start_kong({
          -- set the strategy
          database   = strategy,
          -- use the custom test template to create a local mock server
          nginx_conf = "spec/fixtures/custom_nginx.template",
          -- make sure our plugin gets loaded
          plugins = "bundled," .. PLUGIN_NAME,
          -- write & load declarative config, only if 'strategy=off'
          declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
        }))

        admin_client = helpers.admin_client()
      end)

      it("should not save with empty config", function()
        local res = assert(admin_client:send {
          method  = "POST",
          path    = "/plugins",
          body    = {
            name  = PLUGIN_NAME,
            route = { id = route.id },
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        local body = assert.res_status(400, res)
        local json = cjson.decode(body)
        local msg = [[at least one of these fields must be non-empty: ]] ..
                    [['config.second', 'config.minute', 'config.hour', ]] ..
                    [['config.day', 'config.month', 'config.year']]
        assert.same({
          code = Errors.codes.SCHEMA_VIOLATION,
          fields = {
            ["@entity"] = { msg }
          },
          message = "schema violation (" .. msg .. ")",
          name = "schema violation",
        }, json)
      end)

      it("should save with proper config", function()
        local res = assert(admin_client:send {
          method  = "POST",
          path    = "/plugins",
          body    = {
            name  = PLUGIN_NAME,
            route = { id = route.id },
            config           = {
              second = 10
            }
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        local body = cjson.decode(assert.res_status(201, res))
        assert.equal(10, body.config.second)
      end)

      if strategy == "off" then
        it("sets policy to local by default on dbless", function()
          local id = "bac2038a-205c-4013-8830-e6dde503a3e3"
          local res = admin_client:post("/config", {
            body = {
              _format_version = "1.1",
              plugins = {
                {
                  id = id,
                  name = PLUGIN_NAME,
                  config = {
                    second = 10
                  }
                }
              }
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = cjson.decode(assert.res_status(201, res))
          assert.equal("local", body.plugins[id].config.policy)
        end)

        it("does not allow setting policy to cluster on dbless", function()
          local id = "bac2038a-205c-4013-8830-e6dde503a3e3"
          local res = admin_client:post("/config", {
            body = {
              _format_version = "1.1",
              plugins = {
                {
                  id = id,
                  name = PLUGIN_NAME,
                  config = {
                    policy = "cluster",
                    second = 10
                  }
                }
              }
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = cjson.decode(assert.res_status(400, res))
          assert.equal("expected one of: local, redis", body.fields.plugins[1].config.policy)
        end)

      else
        it("sets policy to cluster by default", function()
          local res = admin_client:post("/plugins", {
            body    = {
              name  = PLUGIN_NAME,
              config = {
                second = 10
              }
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = cjson.decode(assert.res_status(201, res))
          assert.equal("cluster", body.config.policy)
        end)
      end
    end)
  end)
end
