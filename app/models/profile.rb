class Profile < ApplicationRecord
  require 'csv'

  FILE_HEADER = %W[
    姓
    名
    性别
    生日
    身份证
    邮箱
    电话
    单位名称
    职业
    职级
    省份
    城市
    地址
    邮编
    PC139
    PC150
    PC151
    PC167
  ]

  def profile_row_info
    [
      self.firstname,
      self.lastname,
      self.gender,
      self.birthday,
      self.id_num,
      self.email,
      self.cellphone,
      self.employer,
      self.occupation,
      self.position,
      self.province,
      self.city,
      self.address,
      self.zipcode,
      self.PC139,
      self.PC150,
      self.PC151,
      self.PC167
    ]
  end

  def check_response(response)
    reg1 = /Flag&gt;(.*)&lt;\/Flag/
    reg1.match(response)
    if $1.include?('FALSE')
      reg2 = /Message&gt;(.*)&lt;\/Message/
      reg2.match(response)
    end
    return $1
  end

  def full_name
    self.firstname + self.lastname
  end

  class << self
    def import_csv
      content = CSV.read('/Users/spiderevgn/project/metlife/2017_06_25_2.csv')
      content.shift
      content.each do |row|
        Profile.create(
          firstname: row[0],
          lastname: row[1],
          gender: row[2],
          birthday: row[3],
          id_num: row[4],
          email: row[5],
          cellphone: row[6],
          employer: row[7],
          occupation: row[8],
          position: row[9],
          province: row[10],
          city: row[11],
          address: row[12],
          zipcode: row[13]
          )
      end
    end

    def import_xlsx
      content = Roo::Spreadsheet.open('/Users/spiderevgn/project/metlife/2017_06_25_2.xlsx')
      # 姓名,身份证,邮箱,电话,单位名称,职业,职级,省份,城市,地址,邮编
      num = content.sheet('Sheet1').count
      content.sheet('Sheet1').first(num).each do |row|
        fullname  = row[0].gsub(' ','')
        # 512928197108036312
        year  = row[1][6..9]
        month = row[1][10..11]
        day   = row[1][12..13]

        unless 2017 - year.to_i > 60
          Profile.create(
            firstname: fullname[0],
            lastname: fullname[1..-1],
            gender: row[1][-2] == 1 ? '男' : '女',
            birthday: year + '-' + month + '-' + day,
            id_num: row[1],
            email: row[2],
            cellphone: row[3],
            employer: row[4],
            occupation: row[5],
            position: row[6],
            province: row[7],
            city: row[8],
            address: row[9],
            zipcode: row[10]
            )
        end
      end
    end

    def start_to_send
      # Profile.find_each(batch_size: 100, start: 5936, finish: 5918) do |pf|
      Profile.find_each(start: 7204) do |pf|
        # pf = Profile.find(6203);
      # Profile.last(3).each do |pf|
        ['PC0000000139', 'PC0000000151', 'PC0000000150', 'PC0000000167'].each do |present_code|
          response = Profile.send_to_metlife(pf, present_code)
          case present_code
          when 'PC0000000139'
            pf.update(PC139: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000151'
            pf.update(PC151: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000150'
            pf.update(PC150: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000167'
            pf.update(PC167: pf.check_response(response.to_s))
            pf.save
          end
        end
      end
    end

    # Build xml file.
    def build_xml_of_free_insurance(profile, present_code)
      data = ''
      xml = ::Builder::XmlMarkup.new(target: data, indent: 0)
      # xml.instruct!
      xml.instruct! :xml, version: "1.0", encoding: "GBK"
      xml.Records {
        xml.Record {
          xml.Customer {
            xml.Key Profile.generate_free_insurance_id
            xml.ChannelType 'aishanxing'
            xml.FromSystem 'AiShanXing'
            xml.Name profile.full_name
            xml.Sex profile.gender ? 'Male' : 'Female'
            xml.Birthday profile.birthday.to_s
            xml.Document profile.id_num
            xml.DocumentType 'IdentityCard'
            xml.Email profile.email
            xml.Mobile profile.cellphone
            xml.ContactState {
              xml.Name profile.province
            }
            xml.ContactCity {
              xml.Name profile.city
            }
            xml.ContactAddress profile.address
            xml.Occupation {
              xml.Code '0001001'
            }
            # 没有description
            xml.Description
          }
          xml.Task {
            xml.CallList {
              xml.Name ''
            }
            xml.Campaign {
              xml.Name ''
            }
          }
          xml.Activity {
            xml.Code ''
            xml.Present {
              xml.Code present_code
            }
            xml.TSR {
              xml.Code '805095'
            }
            xml.DonateTime Date.current.to_s(:db)
            xml.SMS '1'
            xml.FlightNo
            xml.ValidTime
          }
        }
      }

      return data
    end

    # Send the xml via SOAP
    def send_to_metlife(profile, present_code)
      # pc = Array['PC0000000139', 'PC0000000151', 'PC0000000150', 'PC0000000167']
      # Connect to MetLife SOAP API via wsdl.
      client = Savon.client(wsdl: "http://icare.metlife.com.cn/services/YSW2ICareSave?wsdl", encoding: "GBK")
     
      msg = Profile.build_xml_of_free_insurance(profile, present_code)

      # Debug the API performance.
      puts 'XXXXXXXXXXXXXXXXXX'
      puts msg
      puts 'XXXXXXXXXXXXXXXXXX'

      # response = Hash.new
      
      # msg.each do |key, message|
      #   response[key] = client.call(:do_request, message: { xml_input: message })
      # end

      response = client.call(:do_request, message: { xml_input: msg })

      # Debug the API performance.
      puts '-----------------------'
      puts response
      puts '-----------------------'

      return response
    end

    # def response_from_metlife(response)
    #   if response.nil?
    #     return nil
    #   else
    #     result = Hash.new
    #     response.each do |key, response|
    #       response_body = Nokogiri::XML(response.hash[:envelope][:body][:do_request_response][:do_request_return])
    #       result[key] = [response_body.xpath("//FreeInsureNo").text]
    #     end
    #   end

    #   return result
    # end

    def generate_free_insurance_id
      return 'AiShanXing' + DateTime.current.in_time_zone('Beijing').to_s(:number) + ('0'..'9').to_a.shuffle[0..3].join
    end

    def to_csv
      CSV.open("/Users/spiderevgn/project/metlife/response_0422.csv", "wb") do |csv|
        csv << FILE_HEADER
        Profile.find_each(start: 5960) do |pf|
          csv << pf.profile_row_info
        end
      end
    end

    def convert_wrong_unicode_to_chinese
      Profile.find_each(batch_size: 500) do |pf|
        ['PC139', 'PC151', 'PC150', 'PC167'].each do |code|
          if pf.send("#{code}").include?('&#x5BFC;&#x5165')
            pf.update("#{code}": '客户已有赠险记录,无法导入!!')
          elsif pf.send("#{code}").include?('&#x4E8E;18&#x4F4D;')
            pf.update("#{code}": '身份证号长度不能小于18位!!')
          end
        end
        pf.save
      end
    end

  end
end
