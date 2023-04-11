









local DynamicDataGrid_mt = Class(DynamicDataGrid)


---Creating dynamic data grid
function DynamicDataGrid.new(size, tileSize, customMt)
    local self = setmetatable({}, customMt or DynamicDataGrid_mt)

    self.tileSize = tileSize or 1
    self.size = size or 20
    self.numRows = math.floor(self.size / self.tileSize) + 1

    self.grid = {}
    for _=1, self.numRows do
        local row = {}
        for _=1, self.numRows do
            table.insert(row, {})
        end
        table.insert(self.grid, row)
    end

    self.lastPosition = {x=0, z=0}
    self.lastIndices = nil

    self.yOffset = 0.05

    return self
end


---Deletes data grid
function DynamicDataGrid:delete()
    self.grid = nil
end
