class Profile < ApplicationRecord
  require 'csv'

  def self.import_csv
    content = CSV.read('/Users/spiderevgn/project/metlife/profile_r2_sql.csv')
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
        employer: '成都市政府',
        occupation: '公务员',
        position: row[9],
        province: '四川省',
        city: '成都市',
        address: row[12],
        zipcode: row[13]
        )
    end
  end

  def self.start_to_send(present_code)
    Profile.find_each(batch_size: 100, start: 5557, finish: 5918) do |pf|
    # pc = Array['PC0000000139', 'PC0000000151', 'PC0000000150', 'PC0000000167']
    # pf = Profile.find(5627)
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

  def check_response(response)
    reg1 = /Flag&gt;(.*)&lt;\/Flag/
    reg1.match(response)
    if $1.include?('FALSE')
      reg2 = /Message&gt;(.*)&lt;\/Message/
      reg2.match(response)
    end
    return $1
  end

  # Build xml file.
  def self.build_xml_of_free_insurance(profile, present_code)
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
  def self.send_to_metlife(profile, present_code)
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

  # def self.response_from_metlife(response)
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

  def self.generate_free_insurance_id
    return 'AiShanXing' + DateTime.current.in_time_zone('Beijing').to_s(:number) + ('0'..'9').to_a.shuffle[0..3].join
  end

  def full_name
    self.firstname + self.lastname
  end


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

  def self.to_csv
    CSV.open("/Users/spiderevgn/project/metlife/response.csv", "wb") do |csv|
      csv << FILE_HEADER
      Profile.find_each(batch_size: 200) do |pf|
        csv << pf.profile_row_info
      end
    end
  end

  # 第一次传2000条时结果检测用的方法，之后传输时对response加了正则判断，以下方法就不用了
#   def self.generate_wrong_message
#     CSV.open("/Users/spiderevgn/project/metlife/wrong_message.csv", "wb") do |csv|
#       csv << ["PC139", "PC150", "PC151", "PC167"]
#       Profile.find_each(batch_size: 200) do |pf|
#         csv << [
#           pf.PC139.include?('FALSE') ? pf.PC139 : " ",
#           pf.PC150.include?('FALSE') ? pf.PC150 : " ",
#           pf.PC151.include?('FALSE') ? pf.PC151 : " ",
#           pf.PC167.include?('FALSE') ? pf.PC167 : " "
#         ]
#       end
#     end
#   end

#   def self.check_wrong_item_number
#     all = 0
#     repeat = 0
#     idnum = 0
#     Profile.all.each do |pf|
#       if pf.PC139.include?('FALSE')
#         all += 1
#       end
#       if pf.PC150.include?('FALSE')
#         all += 1
#       end
#       if pf.PC151.include?('FALSE')
#         all += 1
#       end
#       if pf.PC167.include?('FALSE')
#         all += 1
#       end

#       if pf.PC139.include?('&#x5BFC;&#x5165')
#         repeat += 1
#       end
#       if pf.PC150.include?('&#x5BFC;&#x5165')
#         repeat += 1
#       end
#       if pf.PC151.include?('&#x5BFC;&#x5165')
#         repeat += 1
#       end
#       if pf.PC167.include?('&#x5BFC;&#x5165')
#         repeat += 1
#       end

#       if pf.PC139.include?('&#x4E8E;18&#x4F4D;')
#         idnum += 1
#       end
#       if pf.PC150.include?('&#x4E8E;18&#x4F4D;')
#         idnum += 1
#       end
#       if pf.PC151.include?('&#x4E8E;18&#x4F4D;')
#         idnum += 1
#       end
#       if pf.PC167.include?('&#x4E8E;18&#x4F4D;')
#         idnum += 1
#       end

#     end
#     puts "-------------------------------"
#     puts "all: " + all.to_s
#     puts "repeat: " + repeat.to_s
#     puts "idnum: " + idnum.to_s
#   end
end
