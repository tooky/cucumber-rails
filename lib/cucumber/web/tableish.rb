require 'nokogiri'

module Cucumber
  module Web
    module Tableish
      # This method returns an Array of Array of String, using CSS3 selectors.
      # This is particularly handy when using Cucumber's Table#diff! method.
      #
      # The +row_selector+ argument must be a String, and picks out all the rows
      # from the web page's DOM. If the number of cells in each row differs, it
      # will be constrained by (or padded with) the number of cells in the first row
      #
      # The +column_selectors+ argument must be a String or a Proc, picking out
      # cells from each row. If you pass a Proc, it will be yielded an instance
      # of Nokogiri::HTML::Element.
      #
      # == Example with a table
      #
      #   <table id="tools">
      #     <tr>
      #       <th>tool</th>
      #       <th>dude</th>
      #     </tr>
      #     <tr>
      #       <td>webrat</td>
      #       <td>bryan</td>
      #     </tr>
      #     <tr>
      #       <td>cucumber</td>
      #       <td>aslak</td>
      #     </tr>
      #   </table>
      #
      #   t = tableish('table#tools tr', 'td,th')
      #
      # == Example with a dl
      #
      #   <dl id="tools">
      #     <dt>webrat</dt>
      #     <dd>bryan</dd>
      #     <dt>cucumber</dt>
      #     <dd>aslak</dd>
      #   </dl>
      #
      #   t = tableish('dl#tools dt', lambda{|dt| [dt, dt.next.next]})
      #
      def tableish(row_selector, column_selectors)
        html = defined?(Capybara) ? body : response_body
        _tableish(html, row_selector, column_selectors)
      end

      def _tableish(html, row_selector, column_selectors) #:nodoc
        Table.new(html, row_selector, column_selectors).to_a
      end

      class Table

        def initialize(html, row_selector, column_selectors)
          @doc, @row_selector, @column_selectors = Nokogiri::HTML(html), row_selector, column_selectors
          @table = [] 
          parse_table
        end

        def to_a
          max_columns = @table.inject(0) {|max, row| [max, row.length].max}
          @table.map do |row|
            maximise_row_length(row, max_columns)
            remove_nil_cells(row)
          end
        end

        private
        def parse_table
          rows.each_with_index do |row, row_index|
            row.cells(@column_selectors).each do |cell|
              add_to_row(row_index, cell)
            end
          end
        end

        def remove_nil_cells(row)
          row.map {|cell| cell.nil? ? '' : cell}
        end

        def maximise_row_length(row, length)
          row[length - 1] ||= nil
        end

        def add_to_row(row_index, cell)
          cell_index = next_free_cell_for(row_index)
          cell.colspan.times do |x|
            cell.rowspan.times do |y|
              set_cell(x + cell_index, y + row_index, '')
            end
          end
          set_cell(cell_index, row_index, cell.value)
        end

        def set_cell(cell_index, row_index, value)
          @table[row_index] ||= []
          @table[row_index][cell_index] = value
        end

        def next_free_cell_for(row_index)
          return 0 if @table[row_index].nil?
          @table[row_index].index(nil) || @table[row_index].length
        end

        def rows
          @doc.search(@row_selector).map { |row| Row.new row }
        end
      end
      
      class Row
        def initialize(node)
          @row = node
        end

        def cells(selectors)
          cell_nodes(selectors).map { |node| Cell.new node }
        end

        def cell_nodes(selectors)
          case(selectors)
          when String
            @row.search(selectors)
          when Proc
            selectors.call(@row)
          end
        end
      end

      class Cell
        def initialize(node)
          @cell = node
        end

        def value
          case @cell
            when String then @cell.strip
            when nil then ''
            else @cell.text.strip
          end
        end

        def rowspan
          span('row')
        end

        def colspan
          span('col')
        end

        private
        def max(x,y)
          [x,y].max
        end

        def span(type)
          @cell.is_a?(Nokogiri::XML::Node) ? max(@cell.attributes["#{type}span"].to_s.to_i, 1) : 1
        end

      end

    end
  end
end

World(Cucumber::Web::Tableish)
