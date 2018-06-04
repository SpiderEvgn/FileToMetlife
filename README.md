# README

1. 把 xlsx 文档导入 import_data 文件夹

2. 把第一行改成 “姓名 身份证号  邮箱  手机号 单位  职业  职级  省份  城市  地址  邮编”，然后调整数据

3. 进入 container

        docker exec -it filetometlife_web_1 bash
        rails c

4. 记下当前数据库中最后一条记录的 id 号

        Profile.last.id      # 比如：1000

5. 测试数据 (不用 .xlsx 后缀，结果保存在 import_results/import_results_new_file.csv)

        Profile.import_xlsx 'new_file'

6. 检查结果，确认无误，导入数据

        Profile.import_xlsx 'new_file', true

7. 发送新导入数据

        Profile.start_to_send 1001

8. 将返回的错误结果由 utf8 转码为中文

        Profile.convert_wrong_unicode_to_chinese 1001