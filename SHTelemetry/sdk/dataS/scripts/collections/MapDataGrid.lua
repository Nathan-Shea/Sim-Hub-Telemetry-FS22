---A map data grid that splits a map in multiple sections









local MapDataGrid_mt = Class(MapDataGrid, DataGrid)


---Creating data grid
-- @param integer mapSize map size
-- @param integer blocksPerRowColumn blocks per row and column
-- @param table customMt custom metatable
-- @return table instance instance of object
function MapDataGrid.new(mapSize, blocksPerRowColumn, customMt)
    local self = DataGrid.new(blocksPerRowColumn, blocksPerRowColumn, customMt or MapDataGrid_mt)

    self.blocksPerRowColumn = blocksPerRowColumn
    self.mapSize = mapSize
    self.blockSize = self.mapSize/self.blocksPerRowColumn

    return self
end




---@param float worldZ world position z
-- @return table value value at the given position
function MapDataGrid:getValueAtWorldPos(worldX, worldZ)
    local rowIndex, colIndex = self:getRowColumnFromWorldPos(worldX, worldZ)
    return self:getValue(rowIndex, colIndex), rowIndex, colIndex
end




---@param float worldZ world position z
-- @param table value value at the given position
function MapDataGrid:setValueAtWorldPos(worldX, worldZ, value)
    local rowIndex, colIndex = self:getRowColumnFromWorldPos(worldX, worldZ)
    self:setValue(rowIndex, colIndex, value)
end




---@param float worldZ world position z
-- @return integer row row
-- @return integer column column
function MapDataGrid:getRowColumnFromWorldPos(worldX, worldZ)
    local mapSize = self.mapSize
    local blocksPerRowColumn = self.blocksPerRowColumn

    local x = (worldX + mapSize*0.5) / mapSize
    local z = (worldZ + mapSize*0.5) / mapSize

    local row = MathUtil.clamp(math.ceil(blocksPerRowColumn*z), 1, blocksPerRowColumn)
    local column = MathUtil.clamp(math.ceil(blocksPerRowColumn*x), 1, blocksPerRowColumn)

--    log(worldX, worldZ, " -> ", (worldX + self.mapSize*0.5), (worldZ + self.mapSize*0.5), z, x, row, column)

    return row, column
end
