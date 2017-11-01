#!/usr/bin/env ruby

#+
# This is a very rough proof-of-concept script that is intended to help in the processing of
# manuals that have been scanned as multiple logical pages per physical page. A typical
# example would be a manual that is a booklet of A5 pages that, when unstapled, is actually
# A4 physical pages each of which contains two logical A5 pages. The script should process
# this automatically to produce a PDF that matches what would have been produced had the
# original manual been scanned a page at a time (and cropped to A5 if necessary).
#-

# Converts an image_type string (e.g. "jpeg") into a pdfimages output format option.
def image_type_to_pdfimages_option(image_type)
  case image_type
  when /^jpeg$/ix then return "-j"
  end
  raise("Unrecognised image type: [#{image_type}]")
end
# Check that all pages in a given PDF file are images using the same encoding
#
def find_page_image_format(pdf_file)
  output = `pdfimages -list #{pdf_file}`
  # The result from pdfimages should look like this:
  #
  # page   num  type   width height color comp bpc  enc interp  object ID x-ppi y-ppi size ratio
  # --------------------------------------------------------------------------------------------
  #    1     0 image    2480  3507  gray    1   8  jpeg   no         6  0   300   300  325K 3.8%
  #    2     1 image    2480  3507  gray    1   8  jpeg   no        11  0   300   300  141K 1.7%
  #    3     2 image    2480  3507  gray    1   8  jpeg   no        16  0   300   300  706K 8.3%
  #
  # So the image encoding should be in column [9] (where the page number is in column [0]).
  #
  # Run through the pages and ensure that they are all the same type.
  image_type = nil
  output.each_line() {
    |line|
    next if line =~ /^----/ || line =~ /^page/
    data = line.split(/\s+/)
    image_type ||= data[9]
    image_type = "inconsistent" if image_type != data[9]
  }
  return image_type
end

#
# Original page layout (using a 48 page document as an example).
# 1-RAC means "page 1, rotated anti-clockwise" and
# 2-RCC means "page 2, rotated clockwise".
#
# PDF     Original
# page    page
#
# 1        1-RAC
#         48-RAC
# 2        2-RCC
#         47-RCC
# 3        3-RAC
#         46-RAC
# 4        4-RCC
#         45-RCC
def process_2up(pdf_file, work_dir, prefix, image_type)
  image_option = image_type_to_pdfimages_option(image_type)
  # The output should be work_dir + prefix with a "/" in between, either from work_dir or added in if needed
  output = work_dir + (work_dir[-1] != "/" ? "/" : "") + prefix

  # Extract the PDF pages as the appropriate image type
  result = `pdfimages #{image_option} #{pdf_file} #{output}`

  last_page = 0
  # Split out the image pages into new images, each of which is one page of the original
  # Delete the original image file.
  # TODO .jpg here should be fixed
  # Remember the highest page number (in the original PDF)
  files = Dir.glob(output + "-*.jpg")
  files.each() {
    |file|
    if file =~ /#{prefix}-(\d+).jpg/
      last_page = $1.to_i() unless last_page > $1.to_i()
    else
      next # Do not touch files that do not meet the naming pattern
    end
    puts("process file [#{file}] ... current last page: #{last_page}")
    # Split the page into two.
    `convert -crop 100%x50% +repage #{file} #{file}`
    File.delete(file)
  }

  # The split out pages are numbered [0 ... last_pdf_page -1]
  # From now, consider pages to be [1 ... last_page]
  last_page += 1
  
  # Now we have a set of files with names like #{prefix}-PPP-NN.jpg
  # where PPP is the original PDF page number and NN is 00 for the upper part of the
  # original page and 01 for the lower part of the original page.
  # Rotate +90 when PPP is even and +270 (i.e. -90) when PPP is odd.
  1.upto(last_page) {
    |ppp|
    rotation = ppp.odd?() ? 90 : 270
    ["0", "1"].each() {
      |nn|
      fname = "#{output}-%3.3d-#{nn}.jpg" % (ppp - 1)
      output_page_number = (nn == "0") ? ppp : (2*last_page) - (ppp -1)
      puts("Working on #{fname} for output page #{output_page_number}")
      `convert -rotate #{rotation} #{fname} #{output}-final-#{"%4.4d" % output_page_number}.jpg`
      File.delete(fname)
      output_page_number += 1
    }
  }

  # Put all the final files together into one PDF
  `convert #{output}-final-*.jpg #{output}-final.pdf`
  puts("Resulting pdf: #{output}-final.pdf")
end

pdf_file = ARGV.shift()
work_dir = ARGV.shift()

# Check that the work area is writeable
unless File.writable?(work_dir)
  raise("Files cannot be written to the specified working directory, #{work_dir}")
end

file_name = File.basename(pdf_file) # to be used as a prefix
puts("Processing [#{pdf_file}] and using work area [#{work_dir}]")

image_type = find_page_image_format(pdf_file)
puts("Image type: #{image_type}")

process_2up(pdf_file, work_dir, file_name, image_type)
